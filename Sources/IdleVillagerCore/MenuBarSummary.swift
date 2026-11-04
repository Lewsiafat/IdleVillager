/// 選單列摘要的純值模型，由 Store 的計數與連線狀態推導；不含任何 Session 名稱。
public struct MenuBarSummary: Hashable, Sendable {
    /// 摘要的呈現模式。
    public enum Mode: Hashable, Sendable {
        /// 已連線且至少有一個 Agent Session，顯示各類別數量。
        case normal
        /// 與 Herdr 斷線或重連中；不輸出任何數字，避免顯示過期的舊數量。
        case disconnected
        /// 已連線但沒有任何 Agent Session；與斷線是不同的呈現。
        case zeroAgents
    }

    /// 選單列上的一個數量類別。
    public struct Item: Hashable, Sendable {
        public var state: NormalizedState
        public var icon: String
        public var count: Int
        /// 這個類別是否出現在選單列上。
        public var isVisible: Bool

        public init(state: NormalizedState, icon: String, count: Int, isVisible: Bool) {
            self.state = state
            self.icon = icon
            self.count = count
            self.isVisible = isVisible
        }
    }

    public var mode: Mode
    /// 依固定順序（Working、Needs Approval、Idle）排列的類別。
    public var items: [Item]
    /// Done、Error、Unknown 任一大於 0 時為 true，選單列以小標記提示這些不在預設數量中的狀態。
    public var hasHiddenStates: Bool

    public init(counts: StateCounts, connectionState: ConnectionState, alwaysShowZero: Bool = false) {
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
        items = [(NormalizedState.working, "⚒"), (.needsApproval, "✋"), (.idle, "💤")].map { state, icon in
            Item(state: state, icon: icon, count: counts[state], isVisible: alwaysShowZero || counts[state] > 0)
        }
        hasHiddenStates = counts.done > 0 || counts.error > 0 || counts.unknown > 0
    }

    /// 由 Store snapshot 產生摘要。
    public init(snapshot: StoreSnapshot, alwaysShowZero: Bool = false) {
        self.init(counts: snapshot.counts, connectionState: snapshot.connectionState, alwaysShowZero: alwaysShowZero)
    }
}

/// 把摘要模型轉成選單列文字。
public enum MenuBarSummaryFormatter {
    /// 選單列文字，例如 `⚒ 3  ✋ 2  💤 1`。
    public static func text(for summary: MenuBarSummary) -> String {
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

    /// 斷線模式的固定文字，不含任何數字。
    public static let disconnectedText = "⚠ 斷線"

    /// 零 Agent 模式的固定文字。
    public static let zeroAgentsText = "0 個 Agent"

    /// 有 Done、Error 或 Unknown 時接在尾端的小標記。
    public static let hiddenStatesMarker = "•"
}
