# 清單關閉時清除切換失敗提示，並修正列的手指游標（#57）

- **分支:** `fix/popover-clear-failure`
- **日期:** 2026-11-12

## 描述
`MenuBarExtra`（`.window` 樣式）關閉清單時只把視窗藏起來，SwiftUI 的 `onDisappear` 不會觸發。
因此 `SessionPopoverView` 依賴 `onDisappear` 呼叫 `focusCoordinator.clearFailure()` 的寫法沒有生效，
重新打開清單時還會看到上一次的切換失敗提示。改成依據 `WindowVisibilityObserver` 寫入的 `isVisible`，
清單由可見變成不可見時清除提示。

處理過程中發現列的手指游標從 v0.1.0 起就沒有顯示過：`NSCursor.push()` 設好的游標，
馬上被 AppKit 依「滑鼠底下接收點擊的 view」重新設回箭頭，而用 SwiftUI `onTapGesture` 時，接收點擊的是 SwiftUI 視窗本身。
改用 `ClickableRowArea`（AppKit view）負責點擊、hover 與 cursor rect，移除手動 push、pop 游標的程式碼。
清單關閉時另外重設列的 hover 反白。

## 任務清單
- [x] `SessionPopoverView`：`isVisible` 由 true 變 false 時呼叫 `clearFailure()`，移除依賴 `onDisappear` 的寫法
- [x] `SessionRowView`：改用 `ClickableRowArea` 處理點擊、hover 與手指游標
- [x] `SessionRowView`：`popoverIsVisible` 變 false 時重設 `isHovered`
- [x] `swift build` 與 `swift test` 通過（271 個測試）
- [x] 以 `performClick` 除錯碼驗證：製造切換失敗，關閉清單後 `lastFailure` 為 nil（修正前仍存在）
- [x] 使用者手動確認：手指游標、hover 反白、捲動、拖出取消、點擊切換都正確
- [x] `CHANGELOG.md` 的 `[Unreleased]` 補上這次修正
