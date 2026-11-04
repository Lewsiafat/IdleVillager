import Foundation

/// 選單列上的一個角色，代表一個 Agent Session。不含 Session 名稱，只有種類與狀態。
public struct MenuBarCharacterItem: Hashable, Sendable, Identifiable {
    public var agentSessionID: AgentSessionID
    public var agentKind: AgentKind
    public var normalizedState: NormalizedState
    /// 狀態圖示，與 Popover 清單相同（⚒ ✋ ✓ 💤 ! ?），讓狀態不只靠角色或顏色辨識。
    public var icon: String

    public init(agentSessionID: AgentSessionID, agentKind: AgentKind, normalizedState: NormalizedState, icon: String) {
        self.agentSessionID = agentSessionID
        self.agentKind = agentKind
        self.normalizedState = normalizedState
        self.icon = icon
    }

    public var id: AgentSessionID { agentSessionID }
}

/// 選單列實際要呈現的內容。
public enum MenuBarDisplay: Hashable, Sendable {
    /// 數量模式，沿用 `MenuBarSummary` 與 `MenuBarSummaryFormatter` 的摘要文字。
    case counts
    /// 少量角色模式，每個 Session 一個靜態角色，依清單優先度排列。
    case characters([MenuBarCharacterItem])
}

/// 依選單列模式與 Session 數量決定選單列呈現數量還是角色的純值模型。
///
/// 只有在使用者選擇少量角色模式、已連線，且 Session 數量介於 1 與門檻（含）之間時才呈現角色；
/// 超過門檻、沒有 Session 或斷線時自動回到數量模式，避免把選單列撐爆或顯示過期角色。
public struct MenuBarCharacterMode: Hashable, Sendable {
    /// 預設門檻：最多 4 個 Session 時顯示角色。
    public static let defaultFewCharactersThreshold = 4

    public var display: MenuBarDisplay

    /// - Parameters:
    ///   - snapshot: Session Store 的快照。
    ///   - menuBarMode: 使用者選擇的選單列模式。
    ///   - fewCharactersThreshold: 少量角色模式最多顯示的 Session 數量，超過就回到數量模式。
    public init(
        snapshot: StoreSnapshot,
        menuBarMode: MenuBarMode,
        fewCharactersThreshold: Int = MenuBarCharacterMode.defaultFewCharactersThreshold
    ) {
        let count = snapshot.sessions.count
        guard menuBarMode == .fewCharacters,
              snapshot.connectionState == .connected,
              count > 0, count <= fewCharactersThreshold
        else {
            display = .counts
            return
        }
        let items = snapshot.sessions
            .sorted(by: Self.precedes)
            .map { entry in
                MenuBarCharacterItem(
                    agentSessionID: entry.session.agentSessionID,
                    agentKind: AgentKind(rawAgentKind: entry.session.agentKind),
                    normalizedState: entry.normalizedState,
                    icon: SessionListModel.icon(for: entry.normalizedState)
                )
            }
        display = .characters(items)
    }

    /// 從使用者設定取得選單列模式。設定值由呼叫端傳入，模型本身不讀取偏好儲存。
    @MainActor
    public init(
        snapshot: StoreSnapshot,
        settings: AppSettings,
        fewCharactersThreshold: Int = MenuBarCharacterMode.defaultFewCharactersThreshold
    ) {
        self.init(snapshot: snapshot, menuBarMode: settings.menuBarMode, fewCharactersThreshold: fewCharactersThreshold)
    }

    /// 與 Popover 列相同的排序：先比清單優先度，同優先度依 paneLabel（數字以數值比較），再依 agentSessionID。
    private static func precedes(_ lhs: StoreSession, _ rhs: StoreSession) -> Bool {
        let lhsRank = rank(lhs.normalizedState)
        let rhsRank = rank(rhs.normalizedState)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        switch lhs.session.paneLabel.compare(rhs.session.paneLabel, options: .numeric) {
        case .orderedAscending: return true
        case .orderedDescending: return false
        case .orderedSame: return lhs.session.agentSessionID.rawValue < rhs.session.agentSessionID.rawValue
        }
    }

    private static func rank(_ state: NormalizedState) -> Int {
        SessionListModel.priorityOrder.firstIndex(of: state) ?? SessionListModel.priorityOrder.count
    }
}
