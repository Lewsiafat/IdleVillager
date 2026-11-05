/// 一種正規化狀態在畫面上的呈現事實：圖示、短文字與英文名稱。
///
/// 狀態呈現對照表只定義在 `NormalizedState.presentation` 一處；Popover 清單、選單列摘要、
/// 少量角色模式、無障礙文字與衝突描述都從這裡讀取，不另寫自己的 switch。
public struct StatePresentation: Hashable, Sendable {
    /// 狀態圖示：⚒ ✋ ✓ 💤 ! ?。
    public let icon: String
    /// 狀態短文字（GLOSSARY 的用字），清單、選單列與無障礙文字共用，例如「幹活中」「訊號不足」。
    public let shortText: String
    /// 正規化狀態的英文名稱（GLOSSARY 的標題），例如「Needs Approval」，用於衝突描述。
    public let englishName: String

    public init(icon: String, shortText: String, englishName: String) {
        self.icon = icon
        self.shortText = shortText
        self.englishName = englishName
    }
}

extension NormalizedState {
    /// 狀態呈現對照表，是圖示、短文字與英文名稱的唯一來源。
    public var presentation: StatePresentation {
        switch self {
        case .working: StatePresentation(icon: "⚒", shortText: "幹活中", englishName: "Working")
        case .needsApproval: StatePresentation(icon: "✋", shortText: "等核准", englishName: "Needs Approval")
        case .done: StatePresentation(icon: "✓", shortText: "完成", englishName: "Done")
        case .idle: StatePresentation(icon: "💤", shortText: "閒置", englishName: "Idle")
        case .error: StatePresentation(icon: "!", shortText: "錯誤", englishName: "Error")
        case .unknown: StatePresentation(icon: "?", shortText: "訊號不足", englishName: "Unknown")
        }
    }

    /// 狀態圖示，等同 `presentation.icon`。
    public var icon: String { presentation.icon }

    /// 狀態短文字，等同 `presentation.shortText`。
    public var shortText: String { presentation.shortText }

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
