/// 狀態在畫面上的輔助色語意，例如 Popover 狀態膠囊的底色。
///
/// 顏色只是輔助；狀態一定同時有圖示與文字。高對比模式下畫面改用主要前景色或實線框，不依賴這裡的顏色。
public enum StateTint: Hashable, Sendable {
    case green
    case orange
    case yellow
    case red
    case gray
}

extension NormalizedState {
    /// 狀態對應的輔助色：Working 綠、Needs Approval 橘、Done 黃、Error 紅、Idle 與 Unknown 灰。
    public var tint: StateTint {
        switch self {
        case .working: .green
        case .needsApproval: .orange
        case .done: .yellow
        case .error: .red
        case .idle, .unknown: .gray
        }
    }
}
