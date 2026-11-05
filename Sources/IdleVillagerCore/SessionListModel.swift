import Foundation

/// Popover 清單的純值模型，由 Store snapshot 推導。
public struct SessionListModel: Hashable, Sendable {
    /// Popover 底部的來源與連線資訊區。來源名稱來自 Adapter 的來源描述，只出現在這裡。
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

        /// 最後成功更新時間的人類可讀文字，以 `now` 計算相對時間，例如「最後更新：3 分鐘前」。
        ///
        /// 未滿 10 秒（含時鐘誤差造成的未來時間）為「剛剛」，之後依序為秒、分鐘、小時、天，皆無條件捨去；
        /// 從未成功更新時為「尚未成功更新」。
        public func lastUpdatedText(now: Date) -> String {
            guard let lastUpdatedAt else { return "尚未成功更新" }
            let elapsed = Int(now.timeIntervalSince(lastUpdatedAt))
            let relative: String
            switch elapsed {
            case ..<10: relative = "剛剛"
            case ..<60: relative = "\(elapsed) 秒前"
            case ..<3_600: relative = "\(elapsed / 60) 分鐘前"
            case ..<86_400: relative = "\(elapsed / 3_600) 小時前"
            default: relative = "\(elapsed / 86_400) 天前"
            }
            return "最後更新：" + relative
        }

        /// 斷線或重連中、且清單仍保留上次內容時的過期提示；已連線或沒有清單可提示時為 nil。
        public var staleNotice: String? {
            guard connectionState != .connected, lastUpdatedAt != nil else { return nil }
            return "資料可能已過期，以上清單為最後一次成功更新的內容。"
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
        /// 狀態短文字，例如「幹活中」「等核准」「訊號不足」；資料過期時加上後綴「（過期）」，例如「幹活中（過期）」。
        public var stateText: String
        /// 可選的補充說明：等待原因或衝突描述。沒有時為 nil。
        public var detail: String?
        /// 這列的資料是否已過期（來自 Store 的 `isStale`）。
        public var isStale: Bool

        public init(
            id: AgentSessionID,
            paneID: PaneID,
            agentKind: String,
            displayName: String,
            paneLabel: String,
            state: NormalizedState,
            icon: String,
            stateText: String,
            detail: String?,
            isStale: Bool = false
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
            self.isStale = isStale
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
                stateText: SessionListModel.stateText(for: entry.normalizedState)
                    + (entry.isStale ? SessionListModel.staleSuffix : ""),
                detail: entry.conflictNote,
                isStale: entry.isStale
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
    /// Agent Session 總數。斷線或重連中時可能是過期的數字，畫面請改用 `headerStatusText`。
    public var agentCount: Int
    /// Workspace → Tab → 列的三層群組。
    public var workspaces: [WorkspaceGroup]
    public var footer: Footer

    /// Popover 標題右側的狀態文字。
    ///
    /// 已連線時是 Agent 總數，例如「3 個 Agent」，零 Agent 為「0 個 Agent」；
    /// 從未連上為「未連線」，曾連上後斷線為「已斷線」，重連中為「重新連線中」。斷線時不顯示任何數字，避免 0 或過期的舊數量。
    public var headerStatusText: String {
        switch footer.connectionState {
        case .connected: "\(agentCount) 個 Agent"
        case .disconnected: footer.lastUpdatedAt == nil ? "未連線" : "已斷線"
        case .reconnecting: "重新連線中"
        }
    }

    /// 清單沒有任何列時 Popover 顯示的空狀態文字；有列時為 nil。
    ///
    /// 已連線時是明確的零 Agent 狀態，斷線或重連中則說明沒有可顯示的資料，兩者文字不同。
    public var emptyStateText: String? {
        guard workspaces.isEmpty else { return nil }
        return footer.connectionState == .connected ? "目前沒有 Agent Session" : "未連線，沒有可顯示的 Session 資料"
    }

    /// 依優先度排序（`SortRule.priority`）建立清單。
    public init(snapshot: StoreSnapshot) {
        self.init(snapshot: snapshot, sortRule: .priority)
    }

    /// 依指定的排序規則建立清單。
    ///
    /// - `priority`：列、Tab、Workspace 都依清單優先度排序，急件所在的群組浮到最上方。
    /// - `workspaceName`：Workspace 與 Tab 依名稱（數字以數值比較）排序，列仍依優先度。
    /// - `fixed`：Workspace、Tab、列都依穩定 ID 的字串順序排序，不因狀態改變而移動。
    public init(snapshot: StoreSnapshot, sortRule: SortRule) {
        title = "IdleVillager"
        agentCount = snapshot.counts.total
        workspaces = Self.group(snapshot.sessions, sortRule: sortRule)
        footer = Footer(
            sourceName: snapshot.sourceDescription,
            connectionState: snapshot.connectionState,
            connectionText: Self.connectionText(snapshot.connectionState),
            lastUpdatedAt: snapshot.lastUpdatedAt
        )
    }

    private static func group(_ sessions: [StoreSession], sortRule: SortRule) -> [WorkspaceGroup] {
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
                switch sortRule {
                case .priority, .workspaceName:
                    workspaces[w].tabs[t].rows.sort(by: rowPrecedes)
                case .fixed:
                    workspaces[w].tabs[t].rows.sort { $0.id.rawValue < $1.id.rawValue }
                }
            }
            workspaces[w].tabs.sort { lhs, rhs in
                groupPrecedes(sortRule, lhs.topState, lhs.name, lhs.id.rawValue, rhs.topState, rhs.name, rhs.id.rawValue)
            }
        }
        workspaces.sort { lhs, rhs in
            groupPrecedes(sortRule, lhs.topState, lhs.name, lhs.id.rawValue, rhs.topState, rhs.name, rhs.id.rawValue)
        }
        return workspaces
    }

    /// 一組狀態中最高優先度者；空集合為 Unknown。
    static func highestPriority(_ states: [NormalizedState]) -> NormalizedState {
        states.min { rank($0) < rank($1) } ?? .unknown
    }

    /// 群組排序。`priority` 先比內含的最高優先度；`priority` 與 `workspaceName` 接著依名稱，再依 ID；
    /// `fixed` 只依 ID 的字串順序。最後一律以 ID 決定，確保順序穩定。
    private static func groupPrecedes(
        _ sortRule: SortRule,
        _ lhsState: NormalizedState, _ lhsName: String, _ lhsID: String,
        _ rhsState: NormalizedState, _ rhsName: String, _ rhsID: String
    ) -> Bool {
        if sortRule == .priority, rank(lhsState) != rank(rhsState) { return rank(lhsState) < rank(rhsState) }
        if sortRule != .fixed, let order = nameOrder(lhsName, rhsName) { return order }
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

    /// 資料過期的列在狀態短文字後加上的標示。
    public static let staleSuffix = "（過期）"

    private static func connectionText(_ state: ConnectionState) -> String {
        switch state {
        case .connected: "已連線"
        case .disconnected: "已斷線"
        case .reconnecting: "重新連線中"
        }
    }
}

extension SessionListModel {
    /// 依使用者設定的排序規則（`AppSettings.sortRule`）建立清單。設定值由呼叫端傳入，清單模型本身不讀取偏好儲存。
    @MainActor
    public init(snapshot: StoreSnapshot, settings: AppSettings) {
        self.init(snapshot: snapshot, sortRule: settings.sortRule)
    }
}
