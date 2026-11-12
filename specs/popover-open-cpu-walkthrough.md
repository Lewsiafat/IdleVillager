# 清單開著時的 CPU：角色循環動畫改用 Core Animation — Walkthrough

- **分支:** `fix/popover-open-cpu`
- **日期:** 2026-11-13

## 變更摘要
清單開著時，角色的循環動畫（幹活、舉手、躺平）原本用 SwiftUI `PhaseAnimator` 播放，App 的 CPU 約 10%。
現在一個週期的關鍵影格由 Core 描述，App 層交給 Core Animation 無限重複播放，CPU 降到 0.2% 到 0.8%，和關閉動畫時相同。動畫外觀不變。

## 修改的檔案
- `Sources/IdleVillagerCore/CharacterLoopKeyframes.swift`（新增）：`CharacterLoopPose`、`CharacterLoopCurve`、`CharacterLoopKeyframe`、`CharacterLoopKeyframes`，以及 `CharacterLoop.keyframes`。依 `CharacterLoop.parameters` 產生一個週期的關鍵影格，包括靜止時段。
- `Tests/IdleVillagerCoreTests/CharacterLoopKeyframesTests.swift`（新增）：11 個測試，涵蓋頭尾相同可無縫重複、時間遞增、幹活全程在動、舉手在靜止時段不動、Zzz 在靜止時段看不見並且先浮現再飄起淡出。
- `Sources/IdleVillagerApp/CharacterMotionModifiers.swift`：移除 `WorkingBob`、`RaisedHandSway`、`IdleZzz` 三個 `PhaseAnimator` 實作。新增 `CharacterLoopView`（依對象決定動角色本身或小 z）、`ZzzMarker`、`LoopingLayer`（`NSViewRepresentable`）與 `LoopingHostingView`（`NSHostingView` 子類別，把關鍵影格換算成 `CAKeyframeAnimation`）。一次性過渡的 `CharacterTransitionModifier` 不變。
- `docs/04-assets-animation.md`：補上動畫的實作方式與原因。
- `CHANGELOG.md`：`[Unreleased]` 的 Fixed 補上這次修正。
- `specs/popover-open-cpu.md`：規格與任務清單。

## 技術細節
- **量測流程**：暫時在 `IdleVillagerMenuBarApp.init()` 加上除錯碼，用 `performClick` 自動打開清單，再用 `top` 量 8 秒的 CPU。以示範資料（3 個幹活、2 個舉手、1 個躺平）和 release 版執行。動畫關閉時的 0% 作為基準。除錯碼沒有 commit。
- **證實的原因**：
  1. `PhaseAnimator` 用 `delay` 表示的靜止時段仍每一幀更新：把躺平角色的靜止時間拉長 10 倍，量測期間完全不動，CPU 仍約 2.6%。
  2. SwiftUI 推動動畫時，每一幀都要在主執行緒更新 view graph 並重做整個視窗的版面配置（`sample` 中約 80% 在 `layoutIfNeeded`），而且成本和畫面大小無關。
- **排除的方向**：量清單高度的 `onGeometryChange` 只觸發一次；`drawingGroup()` 沒有改善；把角色放進獨立的 `NSHostingView` 也沒有改善。中途試過用 `Task.sleep` 取代 `delay`，舉手與躺平確實下降，但幹活角色不受影響，所以最後全部改用 Core Animation。
- **座標換算**：Core 的角度以順時針為正、抬起以往上為正。`LoopingHostingView` 依上層圖層是否翻轉（`contentsAreFlipped()`）與 `anchorPoint` 換算，以角色底部中央為軸旋轉。
- **動畫的維護**：在 `layout()` 加動畫，因為那時圖層大小才確定。關鍵影格改變（例如狀態從幹活變成舉手）時重新加；發現 AppKit 把動畫移除時也會補回。清單關閉時，原本的 `popoverIsVisible` 會讓 loop 變成 nil，整個 view 被移除，動畫跟著停止。
- **未量的部分**：Core Animation 的動畫由 WindowServer 播放，這台電腦的 WindowServer 背景負擔在 34% 到 42% 之間跳動，無法量出可靠的差異。
- **驗證**：讀取 6 個角色圖層的即時 `presentation()` 數值，確認動畫在播且隨時間改變。使用者目視確認三種動作和正式版一致，關閉再打開清單、切換動畫設定都正常。282 個測試全部通過。
