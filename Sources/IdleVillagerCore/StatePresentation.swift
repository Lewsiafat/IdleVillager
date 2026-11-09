/// 一種正規化狀態在畫面上的呈現事實：圖示、短文字、英文名稱、SF Symbol 名稱與輔助色。
///
/// 狀態呈現對照表只定義在 `NormalizedState.presentation` 一處；Popover 清單、選單列摘要、
/// 少量角色模式、無障礙文字與衝突描述都從這裡讀取，不另寫自己的 switch。
public struct StatePresentation: Hashable, Sendable {
    /// 狀態圖示：⚒ ✋ ✓ 💤 ! ?。
    public let icon: String
    /// 狀態短文字（GLOSSARY 的用字），清單、選單列與無障礙文字共用，例如「幹活中」「訊號不足」。
    /// 依目前的介面語言（`L10n.current`）取自字串表，英文介面為 Working、Unknown 等。
    public let shortText: String
    /// 正規化狀態的英文名稱（GLOSSARY 的標題），例如「Needs Approval」，用於衝突描述。不隨介面語言改變。
    public let englishName: String
    /// 選單列數量模式使用的 SF Symbol 名稱。與 `icon` 同義，只是改用系統圖示，
    /// 讓選單列的狀態圖示大小一致、能跟著選單列的明暗色變化。
    public let symbolName: String
    /// 狀態的輔助色，例如 Popover 狀態膠囊的底色。
    public let tint: StateTint

    public init(icon: String, shortText: String, englishName: String, symbolName: String, tint: StateTint) {
        self.icon = icon
        self.shortText = shortText
        self.englishName = englishName
        self.symbolName = symbolName
        self.tint = tint
    }
}

extension NormalizedState {
    /// 狀態呈現對照表，是圖示、短文字、英文名稱、SF Symbol 名稱與輔助色的唯一來源。
    ///
    /// 輔助色：Working 綠、Needs Approval 橘、Done 黃、Error 紅、Idle 與 Unknown 灰。
    public var presentation: StatePresentation {
        switch self {
        case .working:
            StatePresentation(icon: "⚒", shortText: L10n.text(.stateWorking), englishName: "Working", symbolName: "hammer.fill", tint: .green)
        case .needsApproval:
            StatePresentation(icon: "✋", shortText: L10n.text(.stateNeedsApproval), englishName: "Needs Approval", symbolName: "hand.raised.fill", tint: .orange)
        case .done:
            StatePresentation(icon: "✓", shortText: L10n.text(.stateDone), englishName: "Done", symbolName: "checkmark", tint: .yellow)
        case .idle:
            StatePresentation(icon: "💤", shortText: L10n.text(.stateIdle), englishName: "Idle", symbolName: "zzz", tint: .gray)
        case .error:
            StatePresentation(icon: "!", shortText: L10n.text(.stateError), englishName: "Error", symbolName: "exclamationmark", tint: .red)
        case .unknown:
            StatePresentation(icon: "?", shortText: L10n.text(.stateUnknown), englishName: "Unknown", symbolName: "questionmark", tint: .gray)
        }
    }

    /// 狀態圖示，等同 `presentation.icon`。
    public var icon: String { presentation.icon }

    /// 狀態短文字，等同 `presentation.shortText`。
    public var shortText: String { presentation.shortText }

    /// 選單列數量模式使用的 SF Symbol 名稱，等同 `presentation.symbolName`。
    public var symbolName: String { presentation.symbolName }

    /// 狀態的輔助色，等同 `presentation.tint`。
    public var tint: StateTint { presentation.tint }

    /// 清單優先度，由高到低：Needs Approval > Error > Done > Working > Idle > Unknown。
    /// Popover 清單與少量角色模式都依此排序。
    public static let priorityOrder: [NormalizedState] = [.needsApproval, .error, .done, .working, .idle, .unknown]

    /// 在清單優先度中的名次，數字越小越優先（Needs Approval 為 0）。
    public var priorityRank: Int {
        Self.priorityOrder.firstIndex(of: self) ?? Self.priorityOrder.count
    }

    /// 一組狀態中最高優先度者；空集合為 Unknown。
    public static func highestPriority(_ states: [NormalizedState]) -> NormalizedState {
        states.min { $0.priorityRank < $1.priorityRank } ?? .unknown
    }
}
