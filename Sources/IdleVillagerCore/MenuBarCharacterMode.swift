import Foundation

/// 選單列上的一個角色，代表一個 Agent Session。不含 Session 名稱，只有種類與狀態。
struct MenuBarCharacterItem: Hashable, Sendable, Identifiable {
    var agentSessionID: AgentSessionID
    var agentKind: AgentKind
    var normalizedState: NormalizedState
    /// 狀態圖示，與 Popover 清單相同（⚒ ✋ ✓ 💤 ! ?），讓狀態不只靠角色或顏色辨識。
    var icon: String

    init(agentSessionID: AgentSessionID, agentKind: AgentKind, normalizedState: NormalizedState, icon: String) {
        self.agentSessionID = agentSessionID
        self.agentKind = agentKind
        self.normalizedState = normalizedState
        self.icon = icon
    }

    var id: AgentSessionID { agentSessionID }
}

/// 選單列實際要呈現的內容。
enum MenuBarDisplay: Hashable, Sendable {
    /// 數量模式，由 `MenuBarPresentation` 再以 `MenuBarSummary` 決定數量列、斷線或零 Agent。
    case counts
    /// 少量角色模式，每個 Session 一個靜態角色，依清單優先度排列。
    case characters([MenuBarCharacterItem])
}

/// 依選單列模式與 Session 數量決定選單列呈現數量還是角色的純值模型。
///
/// 這是 `MenuBarPresentation` 的內部實作，App 不直接使用。
///
/// 只有在使用者選擇少量角色模式、已連線，且 Session 數量至少 1 個並低於門檻時才呈現角色；
/// 達到或超過門檻、沒有 Session 或斷線時自動回到數量模式，避免把選單列撐爆或顯示過期角色。
struct MenuBarCharacterMode: Hashable, Sendable {
    /// 預設門檻：Session 數量低於 4 個（也就是最多 3 個）時顯示角色。
    static let defaultFewCharactersThreshold = 4

    var display: MenuBarDisplay

    /// - Parameters:
    ///   - snapshot: Session Store 的快照。
    ///   - menuBarMode: 使用者選擇的選單列模式。
    ///   - fewCharactersThreshold: 少量角色門檻。Session 數量低於門檻才顯示角色，達到或超過就回到數量模式。
    init(
        snapshot: StoreSnapshot,
        menuBarMode: MenuBarMode,
        fewCharactersThreshold: Int = MenuBarCharacterMode.defaultFewCharactersThreshold
    ) {
        let count = snapshot.sessions.count
        guard menuBarMode == .fewCharacters,
              snapshot.connectionState == .connected,
              count > 0, count < fewCharactersThreshold
        else {
            display = .counts
            return
        }
        let items = snapshot.sessions
            .sorted { ListOrderKey.precedes($0.listOrderKey, $1.listOrderKey) }
            .map { entry in
                MenuBarCharacterItem(
                    agentSessionID: entry.session.agentSessionID,
                    agentKind: AgentKind(rawAgentKind: entry.session.agentKind),
                    normalizedState: entry.normalizedState,
                    icon: entry.normalizedState.icon
                )
            }
        display = .characters(items)
    }

    /// 從使用者設定取得選單列模式。設定值由呼叫端傳入，模型本身不讀取偏好儲存。
    @MainActor
    init(
        snapshot: StoreSnapshot,
        settings: AppSettings,
        fewCharactersThreshold: Int = MenuBarCharacterMode.defaultFewCharactersThreshold
    ) {
        self.init(snapshot: snapshot, menuBarMode: settings.menuBarMode, fewCharactersThreshold: fewCharactersThreshold)
    }
}
