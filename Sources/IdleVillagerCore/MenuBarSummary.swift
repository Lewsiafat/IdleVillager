/// 選單列摘要的純值模型，由 Store 的計數與連線狀態推導；不含任何 Session 名稱。
///
/// 這是 `MenuBarPresentation` 的內部實作，App 不直接使用。
struct MenuBarSummary: Hashable, Sendable {
    /// 摘要的呈現模式。
    enum Mode: Hashable, Sendable {
        /// 已連線且至少有一個 Agent Session，顯示各類別數量。
        case normal
        /// 與 Herdr 斷線或重連中；不輸出任何數字，避免顯示過期的舊數量。
        case disconnected
        /// 已連線但沒有任何 Agent Session；與斷線是不同的呈現。
        case zeroAgents
    }

    /// 選單列上的一個數量類別。
    struct Item: Hashable, Sendable {
        var state: NormalizedState
        var icon: String
        var count: Int
        /// 這個類別是否出現在選單列上。
        var isVisible: Bool

        init(state: NormalizedState, icon: String, count: Int, isVisible: Bool) {
            self.state = state
            self.icon = icon
            self.count = count
            self.isVisible = isVisible
        }
    }

    var mode: Mode
    /// 依固定順序（Working、Needs Approval、Idle）排列的類別；開啟 Done 小計數時在 Idle 之後多一個 Done。
    var items: [Item]
    /// 不在選單列數量中的狀態任一大於 0 時為 true，選單列以小標記提示。
    /// 這些狀態是 Error、Unknown，以及未開啟 Done 小計數時的 Done。
    var hasHiddenStates: Bool

    /// - Parameters:
    ///   - alwaysShowZero: 值為 0 的類別也顯示。
    ///   - showDoneCount: 在 Idle 之後加上 Done 小計數 `✓ n`；開啟時 Done 不再算作隱藏狀態。
    init(
        counts: StateCounts,
        connectionState: ConnectionState,
        alwaysShowZero: Bool = false,
        showDoneCount: Bool = false
    ) {
        guard connectionState == .connected else {
            mode = .disconnected
            items = []
            hasHiddenStates = false
            return
        }
        guard counts.total > 0 else {
            mode = .zeroAgents
            items = []
            hasHiddenStates = false
            return
        }
        mode = .normal
        var categories: [NormalizedState] = [.working, .needsApproval, .idle]
        if showDoneCount { categories.append(.done) }
        items = categories.map { state in
            Item(state: state, icon: state.icon, count: counts[state], isVisible: alwaysShowZero || counts[state] > 0)
        }
        let hiddenDone = showDoneCount ? 0 : counts.done
        hasHiddenStates = hiddenDone > 0 || counts.error > 0 || counts.unknown > 0
    }

    /// 由 Store snapshot 產生摘要。
    init(snapshot: StoreSnapshot, alwaysShowZero: Bool = false, showDoneCount: Bool = false) {
        self.init(
            counts: snapshot.counts,
            connectionState: snapshot.connectionState,
            alwaysShowZero: alwaysShowZero,
            showDoneCount: showDoneCount
        )
    }
}

extension MenuBarSummary {
    /// 依使用者設定產生摘要。設定值由呼叫端傳入，摘要本身不讀取偏好儲存。
    @MainActor
    init(snapshot: StoreSnapshot, settings: AppSettings) {
        self.init(
            snapshot: snapshot,
            alwaysShowZero: settings.alwaysShowZeroCounts,
            showDoneCount: settings.showDoneCount
        )
    }
}

/// 把摘要模型轉成選單列文字。`MenuBarPresentation` 的內部實作，App 不直接使用。
enum MenuBarSummaryFormatter {
    /// 選單列文字，例如 `⚒ 3  ✋ 2  💤 1`。
    static func text(for summary: MenuBarSummary) -> String {
        switch summary.mode {
        case .disconnected: return disconnectedText
        case .zeroAgents: return zeroAgentsText
        case .normal: break
        }
        let counts = summary.items
            .filter(\.isVisible)
            .map { "\($0.icon) \($0.count)" }
            .joined(separator: "  ")
        guard summary.hasHiddenStates else { return counts }
        return counts.isEmpty ? hiddenStatesMarker : counts + " " + hiddenStatesMarker
    }

    /// 斷線模式的 SF Symbol 名稱，與文字版的 `⚠` 同義；`MenuBarPresentation` 的斷線內容使用它。
    static let disconnectedSymbolName = "exclamationmark.triangle"

    /// 斷線模式的固定文字，不含任何數字。App 的選單列改畫斷線圖示，這段文字保留給測試與文字版輸出。
    static var disconnectedText: String { L10n.text(.menuBarDisconnected) }

    /// 零 Agent 模式的固定文字。
    static var zeroAgentsText: String { L10n.text(.menuBarZeroAgents) }

    /// 有隱藏狀態（Error、Unknown，或未顯示小計數的 Done）時接在尾端的小標記。
    static let hiddenStatesMarker = "•"
}
