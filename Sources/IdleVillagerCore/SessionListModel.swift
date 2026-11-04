import Foundation

/// Popover 清單的純值模型，由 Store snapshot 推導。
public struct SessionListModel: Hashable, Sendable {
    /// Popover 底部的來源與連線資訊區。Herdr 只出現在這裡。
    public struct Footer: Hashable, Sendable {
        public var sourceName: String
        public var connectionState: ConnectionState
        public var connectionText: String
        /// 最後一次成功取得資料的時間；尚未取得過資料時為 nil。
        public var lastUpdatedAt: Date?

        public init(sourceName: String, connectionState: ConnectionState, connectionText: String, lastUpdatedAt: Date?) {
            self.sourceName = sourceName
            self.connectionState = connectionState
            self.connectionText = connectionText
            self.lastUpdatedAt = lastUpdatedAt
        }
    }

    /// 清單中的一列，代表某個 Pane 裡的一個 Agent Session。
    public struct Row: Hashable, Sendable, Identifiable {
        /// 列的穩定識別碼，即 agentSessionID。
        public var id: AgentSessionID
        /// Focus 的目標 Pane。
        public var paneID: PaneID
        public var agentKind: String
        public var displayName: String
        public var paneLabel: String
        public var state: NormalizedState
        /// 狀態圖示：⚒ ✋ ✓ 💤 ! ?。
        public var icon: String
        /// 狀態短文字，例如「幹活中」「等核准」「訊號不足」。
        public var stateText: String
        /// 可選的補充說明：等待原因或衝突描述。沒有時為 nil。
        public var detail: String?

        public init(
            id: AgentSessionID,
            paneID: PaneID,
            agentKind: String,
            displayName: String,
            paneLabel: String,
            state: NormalizedState,
            icon: String,
            stateText: String,
            detail: String?
        ) {
            self.id = id
            self.paneID = paneID
            self.agentKind = agentKind
            self.displayName = displayName
            self.paneLabel = paneLabel
            self.state = state
            self.icon = icon
            self.stateText = stateText
            self.detail = detail
        }

        init(_ entry: StoreSession) {
            let session = entry.session
            self.init(
                id: session.agentSessionID,
                paneID: session.paneID,
                agentKind: session.agentKind,
                displayName: session.displayName,
                paneLabel: session.paneLabel,
                state: entry.normalizedState,
                icon: SessionListModel.icon(for: entry.normalizedState),
                stateText: SessionListModel.stateText(for: entry.normalizedState),
                detail: entry.conflictNote
            )
        }
    }

    /// Workspace 底下的一個 Tab 群組。
    public struct TabGroup: Hashable, Sendable, Identifiable {
        public var id: TabID
        public var name: String
        public var rows: [Row]

        public init(id: TabID, name: String, rows: [Row]) {
            self.id = id
            self.name = name
            self.rows = rows
        }

        /// 群組內最高優先度的狀態，決定群組的排序。
        public var topState: NormalizedState {
            SessionListModel.highestPriority(rows.map(\.state))
        }
    }

    /// 最上層的 Workspace 群組。
    public struct WorkspaceGroup: Hashable, Sendable, Identifiable {
        public var id: WorkspaceID
        public var name: String
        public var tabs: [TabGroup]

        public init(id: WorkspaceID, name: String, tabs: [TabGroup]) {
            self.id = id
            self.name = name
            self.tabs = tabs
        }

        /// 群組內最高優先度的狀態，決定群組的排序。
        public var topState: NormalizedState {
            SessionListModel.highestPriority(tabs.map(\.topState))
        }
    }

    /// Popover 固定標題。
    public var title: String
    /// Agent Session 總數。
    public var agentCount: Int
    /// Workspace → Tab → 列的三層群組。
    public var workspaces: [WorkspaceGroup]
    public var footer: Footer

    public init(snapshot: StoreSnapshot) {
        title = "IdleVillager"
        agentCount = snapshot.counts.total
        workspaces = Self.group(snapshot.sessions)
        footer = Footer(
            sourceName: "Herdr",
            connectionState: snapshot.connectionState,
            connectionText: Self.connectionText(snapshot.connectionState),
            lastUpdatedAt: snapshot.lastUpdatedAt
        )
    }

    private static func group(_ sessions: [StoreSession]) -> [WorkspaceGroup] {
        var workspaces: [WorkspaceGroup] = []
        for entry in sessions {
            let session = entry.session
            let row = Row(entry)
            if let w = workspaces.firstIndex(where: { $0.id == session.workspaceID }) {
                if let t = workspaces[w].tabs.firstIndex(where: { $0.id == session.tabID }) {
                    workspaces[w].tabs[t].rows.append(row)
                } else {
                    workspaces[w].tabs.append(TabGroup(id: session.tabID, name: session.tabName, rows: [row]))
                }
            } else {
                workspaces.append(WorkspaceGroup(
                    id: session.workspaceID,
                    name: session.workspaceName,
                    tabs: [TabGroup(id: session.tabID, name: session.tabName, rows: [row])]
                ))
            }
        }
        for w in workspaces.indices {
            for t in workspaces[w].tabs.indices {
                workspaces[w].tabs[t].rows.sort(by: rowPrecedes)
            }
            workspaces[w].tabs.sort { lhs, rhs in
                groupPrecedes(lhs.topState, lhs.name, lhs.id.rawValue, rhs.topState, rhs.name, rhs.id.rawValue)
            }
        }
        workspaces.sort { lhs, rhs in
            groupPrecedes(lhs.topState, lhs.name, lhs.id.rawValue, rhs.topState, rhs.name, rhs.id.rawValue)
        }
        return workspaces
    }

    /// 一組狀態中最高優先度者；空集合為 Unknown。
    static func highestPriority(_ states: [NormalizedState]) -> NormalizedState {
        states.min { rank($0) < rank($1) } ?? .unknown
    }

    /// 群組排序：先比內含的最高優先度，同優先度依名稱，再依 ID，確保順序穩定。
    private static func groupPrecedes(
        _ lhsState: NormalizedState, _ lhsName: String, _ lhsID: String,
        _ rhsState: NormalizedState, _ rhsName: String, _ rhsID: String
    ) -> Bool {
        if rank(lhsState) != rank(rhsState) { return rank(lhsState) < rank(rhsState) }
        if let order = nameOrder(lhsName, rhsName) { return order }
        return lhsID < rhsID
    }

    /// 清單排序用的優先度，由高到低：Needs Approval > Error > Done > Working > Idle > Unknown。
    public static let priorityOrder: [NormalizedState] = [.needsApproval, .error, .done, .working, .idle, .unknown]

    /// 數字越小越優先。
    private static func rank(_ state: NormalizedState) -> Int {
        priorityOrder.firstIndex(of: state) ?? priorityOrder.count
    }

    /// 列的排序：先比優先度，同優先度依 paneLabel，再依 agentSessionID，確保順序穩定。
    private static func rowPrecedes(_ lhs: Row, _ rhs: Row) -> Bool {
        if rank(lhs.state) != rank(rhs.state) { return rank(lhs.state) < rank(rhs.state) }
        if let order = nameOrder(lhs.paneLabel, rhs.paneLabel) { return order }
        return lhs.id.rawValue < rhs.id.rawValue
    }

    /// 名稱比較，數字以數值比較（Pane 2 在 Pane 10 之前）；名稱相同時回傳 nil。
    private static func nameOrder(_ lhs: String, _ rhs: String) -> Bool? {
        switch lhs.compare(rhs, options: .numeric) {
        case .orderedAscending: true
        case .orderedDescending: false
        case .orderedSame: nil
        }
    }

    /// 狀態在清單中的圖示。
    public static func icon(for state: NormalizedState) -> String {
        switch state {
        case .working: "⚒"
        case .needsApproval: "✋"
        case .done: "✓"
        case .idle: "💤"
        case .error: "!"
        case .unknown: "?"
        }
    }

    /// 狀態在清單中的短文字。
    public static func stateText(for state: NormalizedState) -> String {
        switch state {
        case .working: "幹活中"
        case .needsApproval: "等核准"
        case .done: "完成"
        case .idle: "閒置"
        case .error: "錯誤"
        case .unknown: "訊號不足"
        }
    }

    private static func connectionText(_ state: ConnectionState) -> String {
        switch state {
        case .connected: "已連線"
        case .disconnected: "已斷線"
        case .reconnecting: "重新連線中"
        }
    }
}
