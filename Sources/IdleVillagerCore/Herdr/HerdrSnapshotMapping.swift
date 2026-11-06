import Foundation

/// 把 Herdr 的 `session.snapshot` 轉成本專案的 `AgentSession`。純函式，不碰 socket。
///
/// 對應規則見 `docs/adr/0002-herdr-socket-api.md` 決策 4 與 6。
public enum HerdrSnapshotMapper {
    /// 只有 `snapshot.agents[]` 會成為 Agent Session；沒有 Agent 的 Pane 不列入。
    ///
    /// - Parameter receivedAt: Adapter 收到這份快照的時間。來源沒有時間戳記，`updatedAt` 一律取它。
    public static func sessions(from snapshot: HerdrWire.Snapshot, receivedAt: Date) -> [AgentSession] {
        let workspaceLabels = Dictionary(
            snapshot.workspaces.map { ($0.workspaceID, $0.label) }, uniquingKeysWith: { first, _ in first }
        )
        let tabLabels = Dictionary(snapshot.tabs.map { ($0.tabID, $0.label) }, uniquingKeysWith: { first, _ in first })
        let paneLabels = Dictionary(snapshot.panes.map { ($0.paneID, $0.label) }, uniquingKeysWith: { first, _ in first })

        return snapshot.agents.map { agent in
            let kind = nonEmpty(agent.agent) ?? ""
            return AgentSession(
                workspaceID: WorkspaceID(agent.workspaceID),
                workspaceName: nonEmpty(workspaceLabels[agent.workspaceID] ?? nil) ?? agent.workspaceID,
                tabID: TabID(agent.tabID),
                tabName: nonEmpty(tabLabels[agent.tabID] ?? nil) ?? agent.tabID,
                paneID: PaneID(agent.paneID),
                paneLabel: nonEmpty(agent.title) ?? nonEmpty(paneLabels[agent.paneID] ?? nil) ?? agent.paneID,
                agentSessionID: AgentSessionID(agent.terminalID),
                agentKind: kind,
                displayName: nonEmpty(agent.terminalTitleStripped) ?? nonEmpty(kind) ?? "Agent",
                rawState: agent.agentStatus,
                updatedAt: receivedAt,
                stateSource: .explicitEvent,
                waitingReason: nil
            )
        }
    }

    /// 快照中有 Agent 的 Pane 集合，也就是要逐個訂閱 `pane.agent_status_changed` 的對象。
    public static func agentPaneIDs(in sessions: [AgentSession]) -> Set<PaneID> {
        Set(sessions.map(\.paneID))
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

/// 對帳快照：比對前後兩份快照，合成 Adapter 事件。純函式。
public enum HerdrSnapshotDiff {
    /// - 舊的有、新的沒有：`sessionRemoved`。
    /// - 舊的沒有、新的有：`sessionAdded`。
    /// - 兩邊都有但 Workspace / Tab / Pane / 名稱等 metadata 改變（例如 Pane 搬移、終端標題更新）：
    ///   以新的完整資料送 `sessionAdded`，Store 會以同一個 ID 取代舊資料。
    /// - 兩邊都有且 metadata 相同：送 `sessionStateChanged`，即使狀態沒變也送，
    ///   讓 `updatedAt` 更新為這次收到快照的時間，Store 才不會把仍存在的 Session 誤判為過期。
    ///
    /// 事件順序：先移除，再依新快照順序送出新增或更新與狀態事件。
    public static func events(from old: [AgentSession], to new: [AgentSession]) -> [AdapterEvent] {
        let oldByID = Dictionary(old.map { ($0.agentSessionID, $0) }, uniquingKeysWith: { first, _ in first })
        let newIDs = Set(new.map(\.agentSessionID))

        var events: [AdapterEvent] = old
            .filter { !newIDs.contains($0.agentSessionID) }
            .map { .sessionRemoved($0.agentSessionID) }

        for session in new {
            guard let previous = oldByID[session.agentSessionID] else {
                events.append(.sessionAdded(session))
                continue
            }
            if metadataDiffers(previous, session) {
                events.append(.sessionAdded(session))
            } else {
                events.append(.sessionStateChanged(
                    session.agentSessionID,
                    rawState: session.rawState,
                    stateSource: session.stateSource,
                    updatedAt: session.updatedAt,
                    waitingReason: session.waitingReason
                ))
            }
        }
        return events
    }

    private static func metadataDiffers(_ lhs: AgentSession, _ rhs: AgentSession) -> Bool {
        lhs.workspaceID != rhs.workspaceID
            || lhs.workspaceName != rhs.workspaceName
            || lhs.tabID != rhs.tabID
            || lhs.tabName != rhs.tabName
            || lhs.paneID != rhs.paneID
            || lhs.paneLabel != rhs.paneLabel
            || lhs.agentKind != rhs.agentKind
            || lhs.displayName != rhs.displayName
    }
}

/// 訂閱連線要送出的 `events.subscribe` 內容。純函式。
public enum HerdrSubscriptionPlan {
    /// 不需要額外參數的生命週期事件。
    ///
    /// 刻意不訂閱 `pane.output_matched`（會帶終端內容）與 `pane.scroll_changed`（與狀態無關）。
    public static let lifecycleTypes: [String] = [
        "workspace.created", "workspace.updated", "workspace.metadata_updated", "workspace.renamed",
        "workspace.moved", "workspace.reordered", "workspace.closed", "workspace.focused",
        "worktree.created", "worktree.opened", "worktree.removed",
        "tab.created", "tab.closed", "tab.focused", "tab.renamed", "tab.moved",
        "pane.created", "pane.closed", "pane.updated", "pane.focused", "pane.moved", "pane.exited",
        "pane.agent_detected",
        "layout.updated",
    ]

    public static let agentStatusChangedType = "pane.agent_status_changed"

    /// 一項訂閱：`type` 加上 `pane.agent_status_changed` 必填的 `pane_id`。
    public struct Subscription: Hashable, Sendable {
        public var type: String
        public var paneID: PaneID?

        public init(type: String, paneID: PaneID? = nil) {
            self.type = type
            self.paneID = paneID
        }

        /// 送進 `params.subscriptions` 的 JSON 物件。
        public var jsonObject: [String: String] {
            var object = ["type": type]
            if let paneID { object["pane_id"] = paneID.rawValue }
            return object
        }
    }

    /// 全部生命週期事件，加上每個已知 Agent Pane 各一項 `pane.agent_status_changed`。Pane 依 ID 排序，結果穩定。
    public static func subscriptions(agentPaneIDs: Set<PaneID>) -> [Subscription] {
        lifecycleTypes.map { Subscription(type: $0) }
            + agentPaneIDs.sorted { $0.rawValue < $1.rawValue }.map {
                Subscription(type: agentStatusChangedType, paneID: $0)
            }
    }
}

/// 收到一則訂閱事件後 Adapter 要做的事。純函式。
public enum HerdrEventAction: Hashable, Sendable {
    /// 已知 Agent Pane 的狀態變更，直接轉成 `sessionStateChanged`。
    case stateChanged(paneID: PaneID, rawState: String)
    /// 生命週期事件：重新取快照並對帳。
    case resnapshot
    /// 不影響 Session 的事件（例如聚焦切換）。
    case ignore

    /// 聚焦類事件只代表使用者切換畫面，不會改變 Session 集合。
    static let ignoredKinds: Set<String> = ["workspace_focused", "tab_focused", "pane_focused", "layout_updated"]

    /// - Parameter knownAgentPanes: 目前快照中有 Agent 的 Pane。狀態事件指向未知 Pane 或 Agent 已消失時改為重新取快照。
    public static func classify(_ envelope: HerdrWire.EventEnvelope, knownAgentPanes: Set<PaneID>) -> HerdrEventAction {
        let kind = envelope.normalizedKind
        if kind == "pane_agent_status_changed" {
            guard
                let paneID = envelope.data.paneID.map(PaneID.init),
                let status = envelope.data.agentStatus,
                knownAgentPanes.contains(paneID),
                envelope.data.agent != nil
            else { return .resnapshot }
            return .stateChanged(paneID: paneID, rawState: status)
        }
        if ignoredKinds.contains(kind) { return .ignore }
        return .resnapshot
    }
}

/// 重新訂閱與重新連線的退避秒數：1、2、4、8、16，之後固定 30。成功後 `reset()` 回到 1。
public struct HerdrBackoff: Sendable, Hashable {
    public static let delays: [TimeInterval] = [1, 2, 4, 8, 16, 30]
    private var index = 0

    public init() {}

    /// 回傳這次要等待的秒數並前進到下一階。
    public mutating func next() -> TimeInterval {
        let delay = Self.delays[min(index, Self.delays.count - 1)]
        index += 1
        return delay
    }

    public mutating func reset() {
        index = 0
    }
}
