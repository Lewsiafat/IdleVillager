import Foundation

/// 選單列呈現：選單列此刻要畫什麼，由 Core 一次決定。
///
/// 輸入 Store 快照、使用者設定、提醒強調程度，以及品牌素材是否存在（由外部注入）；輸出要畫的內容
/// （斷線圖示、零 Agent 文字、數量列或角色列）、每一格或每個角色是否強調、完整的無障礙文字，以及是否使用 template 圖片。
/// App 只依這個值排版與產圖，不自行推論狀態、組無障礙文字或判斷強調。
///
/// 內部依序使用 `MenuBarCharacterMode`（是否顯示角色）與 `MenuBarSummary`（數量與隱藏狀態），
/// 這兩個模型不對 App 公開。選單列文字與無障礙文字都不含任何 Session 名稱。
public struct MenuBarPresentation: Hashable, Sendable {
    /// 選單列要畫的內容。
    public enum Content: Hashable, Sendable {
        /// 斷線或重連中：只畫這個 SF Symbol，不含任何數字，避免顯示過期的舊數量。
        case disconnected(symbolName: String)
        /// 已連線但沒有任何 Agent Session：顯示這段文字（例如「0 個 Agent」），與斷線是不同的呈現。
        case zeroAgents(text: String)
        /// 數量模式：依固定順序排列的可見類別；有隱藏狀態時 `hiddenStatesMarker` 是接在尾端的小標記，否則為 nil。
        case counts([CountCell], hiddenStatesMarker: String?)
        /// 少量角色模式：每個 Session 一個靜態角色，依清單優先度排列。
        case characters([CharacterCell])
    }

    /// 數量列上的一格：一個狀態類別的 SF Symbol 與數量。只列出要顯示的類別。
    public struct CountCell: Hashable, Sendable, Identifiable {
        public var state: NormalizedState
        /// 數量模式用的 SF Symbol 名稱（`NormalizedState.symbolName`）。
        public var symbolName: String
        public var count: Int
        /// 低干擾提醒進行中時這一格是否強調。
        public var isHighlighted: Bool

        public init(state: NormalizedState, symbolName: String, count: Int, isHighlighted: Bool) {
            self.state = state
            self.symbolName = symbolName
            self.count = count
            self.isHighlighted = isHighlighted
        }

        public var id: NormalizedState { state }
    }

    /// 角色列上的一個角色，代表一個 Agent Session。不含 Session 名稱，只有種類與狀態。
    public struct CharacterCell: Hashable, Sendable, Identifiable {
        public var agentSessionID: AgentSessionID
        public var agentKind: AgentKind
        public var normalizedState: NormalizedState
        /// 狀態圖示，與 Popover 清單相同（⚒ ✋ ✓ 💤 ! ?），讓狀態不只靠角色或顏色辨識。
        public var icon: String
        /// 低干擾提醒進行中時這個角色是否強調。
        public var isHighlighted: Bool

        public init(
            agentSessionID: AgentSessionID,
            agentKind: AgentKind,
            normalizedState: NormalizedState,
            icon: String,
            isHighlighted: Bool
        ) {
            self.agentSessionID = agentSessionID
            self.agentKind = agentKind
            self.normalizedState = normalizedState
            self.icon = icon
            self.isHighlighted = isHighlighted
        }

        public var id: AgentSessionID { agentSessionID }
    }

    /// 預設的少量角色門檻：Session 數量低於 4 個（也就是最多 3 個）時顯示角色。
    public static let defaultFewCharactersThreshold = MenuBarCharacterMode.defaultFewCharactersThreshold

    /// 要畫的內容。
    public var content: Content
    /// 選單列的完整無障礙文字，狀態用字與清單相同（`NormalizedState.shortText`）。
    public var accessibilityText: String
    /// 產圖時是否使用 template 圖片，讓系統依選單列外觀自動套用明暗色。
    ///
    /// 角色列含任何品牌素材時為 false，保留品牌標誌原色；其他情況為 true。
    /// 斷線圖示與零 Agent 文字本來就由系統依外觀上色，這個值對它們沒有影響。
    public var usesTemplateImage: Bool

    /// 強調規則，兩種選單列模式共用這一份：提醒進行中時只強調待核准（Needs Approval）。
    ///
    /// 強調只是額外提示，狀態仍由圖示與數量表達，不只靠底色或粗細。
    public static func isHighlighted(_ state: NormalizedState, during emphasis: MenuBarAlertEmphasis) -> Bool {
        emphasis == .emphasized && state == .needsApproval
    }

    /// - Parameters:
    ///   - snapshot: Session Store 的快照。
    ///   - menuBarMode: 使用者選擇的選單列模式。
    ///   - alwaysShowZeroCounts: 數量模式中值為 0 的類別也顯示。
    ///   - showDoneCount: 數量模式在 Idle 之後加上 Done 小計數；開啟時 Done 不再算作隱藏狀態。
    ///   - emphasis: 目前的提醒強調程度（`ApprovalAlertTracker.emphasis(at:)`）。
    ///   - fewCharactersThreshold: 少量角色門檻。Session 數量低於門檻才顯示角色。
    ///   - isBrandAssetAvailable: 查詢某個品牌資源名稱是否存在的函式，由 App 層以 bundle 查找實作，測試可自行注入
    ///     （同 `BrandBody.resolve(agentKind:isAssetAvailable:)`）。
    public init(
        snapshot: StoreSnapshot,
        menuBarMode: MenuBarMode,
        alwaysShowZeroCounts: Bool = false,
        showDoneCount: Bool = false,
        emphasis: MenuBarAlertEmphasis = .none,
        fewCharactersThreshold: Int = MenuBarPresentation.defaultFewCharactersThreshold,
        isBrandAssetAvailable: (String) -> Bool
    ) {
        let characterMode = MenuBarCharacterMode(
            snapshot: snapshot,
            menuBarMode: menuBarMode,
            fewCharactersThreshold: fewCharactersThreshold
        )
        if case .characters(let items) = characterMode.display {
            self = Self.characters(items, emphasis: emphasis, isBrandAssetAvailable: isBrandAssetAvailable)
            return
        }

        let summary = MenuBarSummary(
            counts: snapshot.counts,
            connectionState: snapshot.connectionState,
            alwaysShowZero: alwaysShowZeroCounts,
            showDoneCount: showDoneCount
        )
        usesTemplateImage = true
        switch summary.mode {
        case .disconnected:
            content = .disconnected(symbolName: MenuBarSummaryFormatter.disconnectedSymbolName)
            accessibilityText = L10n.text(
                snapshot.connectionState == .reconnecting ? .connectionReconnecting : .connectionNotConnected
            )
        case .zeroAgents:
            content = .zeroAgents(text: MenuBarSummaryFormatter.zeroAgentsText)
            accessibilityText = L10n.text(.menuBarNoAgentsAccessibility)
        case .normal:
            let visible = summary.items.filter(\.isVisible)
            content = .counts(
                visible.map { item in
                    CountCell(
                        state: item.state,
                        symbolName: item.state.symbolName,
                        count: item.count,
                        isHighlighted: Self.isHighlighted(item.state, during: emphasis)
                    )
                },
                hiddenStatesMarker: summary.hasHiddenStates ? MenuBarSummaryFormatter.hiddenStatesMarker : nil
            )
            var parts = visible.map {
                L10n.text(.menuBarStateCountAccessibility, ["state": $0.state.shortText, "count": String($0.count)])
            }
            if summary.hasHiddenStates {
                // 依設定值決定說法：開啟 Done 小計數時 Done 已在數量列上，隱藏的只剩 Error 與 Unknown。
                parts.append(L10n.text(showDoneCount ? .menuBarHiddenWithDoneShownAccessibility : .menuBarHiddenAccessibility))
            }
            accessibilityText = parts.joined(separator: L10n.text(.clauseSeparator))
        }
    }

    private init(content: Content, accessibilityText: String, usesTemplateImage: Bool) {
        self.content = content
        self.accessibilityText = accessibilityText
        self.usesTemplateImage = usesTemplateImage
    }

    private static func characters(
        _ items: [MenuBarCharacterItem],
        emphasis: MenuBarAlertEmphasis,
        isBrandAssetAvailable: (String) -> Bool
    ) -> MenuBarPresentation {
        let cells = items.map { item in
            CharacterCell(
                agentSessionID: item.agentSessionID,
                agentKind: item.agentKind,
                normalizedState: item.normalizedState,
                icon: item.icon,
                isHighlighted: isHighlighted(item.normalizedState, during: emphasis)
            )
        }
        // 依序列出每個 Agent 的種類與狀態，例如「Codex 等核准，Claude 幹活中」。
        let accessibilityText = cells
            .map { L10n.text(.menuBarCharacterAccessibility, ["kind": kindName($0.agentKind), "state": $0.normalizedState.shortText]) }
            .joined(separator: L10n.text(.clauseSeparator))
        let usesBrandAsset = cells.contains { cell in
            BrandBody.resolve(agentKind: cell.agentKind, isAssetAvailable: isBrandAssetAvailable) != .generic
        }
        return MenuBarPresentation(
            content: .characters(cells),
            accessibilityText: accessibilityText,
            usesTemplateImage: !usesBrandAsset
        )
    }

    /// 無障礙文字中 Agent 種類的顯示名稱；品牌名稱不隨介面語言改變。
    static func kindName(_ kind: AgentKind) -> String {
        switch kind {
        case .claude: "Claude"
        case .codex: "Codex"
        case .gemini: "Gemini"
        case .generic: "Agent"
        }
    }
}

extension MenuBarPresentation {
    /// 依使用者設定（選單列模式、固定顯示 0 數量、Done 小計數）建立選單列呈現。設定值由呼叫端傳入，模型本身不讀取偏好儲存。
    @MainActor
    public init(
        snapshot: StoreSnapshot,
        settings: AppSettings,
        emphasis: MenuBarAlertEmphasis,
        fewCharactersThreshold: Int = MenuBarPresentation.defaultFewCharactersThreshold,
        isBrandAssetAvailable: (String) -> Bool
    ) {
        self.init(
            snapshot: snapshot,
            menuBarMode: settings.menuBarMode,
            alwaysShowZeroCounts: settings.alwaysShowZeroCounts,
            showDoneCount: settings.showDoneCount,
            emphasis: emphasis,
            fewCharactersThreshold: fewCharactersThreshold,
            isBrandAssetAvailable: isBrandAssetAvailable
        )
    }
}
