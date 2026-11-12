# 清單開著時的 CPU：角色循環動畫改用 Core Animation（#56）

- **分支:** `fix/popover-open-cpu`
- **日期:** 2026-11-12

## 描述
清單開著、動畫開啟時，App 的 CPU 約 10%（示範資料：3 個幹活、2 個舉手、1 個躺平）。主執行緒大多在 `-[NSWindow layoutIfNeeded]`。

量測後確認兩個原因：
1. 舉手與躺平用 `PhaseAnimator` 的 `delay` 表示靜止時段，但這段時間 SwiftUI 仍每一幀更新。躺平角色的靜止時間拉長 10 倍、完全不動時，CPU 仍約 2.6%。
2. SwiftUI 推動動畫時，每一幀都要在主執行緒更新 view graph 並重做整個視窗的版面配置，與畫面大小無關。把角色放進獨立的 `NSHostingView` 沒有改善。`drawingGroup()` 也沒有改善。量清單高度的 `onGeometryChange` 只觸發一次，與此無關。

修法：一個週期的關鍵影格由 Core 的 `CharacterLoop.keyframes` 描述（包括靜止時段），App 層的 `LoopingHostingView` 把它換算成 `CAKeyframeAnimation` 交給 Core Animation 無限重複播放。狀態轉換時的一次性過渡維持 SwiftUI `keyframeAnimator`。

## 任務清單
- [x] 建立量測流程（`performClick` 自動打開清單，用 `top` 量 CPU），動畫開／關各量一次作為基準
- [x] 單變數實驗：只留某一種循環、拉長靜止時間、停用高度回寫、`drawingGroup()`、獨立 `NSHostingView`、Core Animation 原型
- [x] Core：新增 `CharacterLoopKeyframes` 與 `CharacterLoop.keyframes`，先寫測試（11 個）
- [x] App：`CharacterLoopView`、`LoopingLayer`、`LoopingHostingView` 取代三個 `PhaseAnimator` 循環
- [x] 量測：清單開著時 CPU 從約 10% 降到 0.2% 到 0.8%（與動畫關閉時相同）
- [x] 確認圖層上真的有動畫，且數值隨時間改變
- [x] 使用者目視確認：三種動作與正式版一致，關閉再打開、切換動畫設定都正常
- [x] `swift test` 通過（282 個測試）
- [x] `CHANGELOG.md`、`docs/04-assets-animation.md` 更新
