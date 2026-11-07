/// 狀態在畫面上的輔助色語意，例如 Popover 狀態膠囊的底色。
///
/// 每種狀態對應哪個顏色定義在 `NormalizedState.presentation`（`StatePresentation.tint`），捷徑為 `NormalizedState.tint`。
/// 顏色只是輔助；狀態一定同時有圖示與文字。高對比模式下畫面改用主要前景色或實線框，不依賴這裡的顏色。
public enum StateTint: Hashable, Sendable {
    case green
    case orange
    case yellow
    case red
    case gray
}
