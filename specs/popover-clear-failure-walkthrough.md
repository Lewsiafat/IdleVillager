# 清單關閉時清除切換失敗提示，並修正列的手指游標 — Walkthrough

- **分支:** `fix/popover-clear-failure`
- **日期:** 2026-11-12

## 變更摘要
清單關閉時，現在會清除上一次的切換失敗提示（#57）。原本的寫法依賴 `onDisappear`，但 `MenuBarExtra` 關閉清單時不會觸發它。
處理過程中也修好了從 v0.1.0 起就沒有顯示過的列手指游標：點擊、hover 與游標改由新的 AppKit view `ClickableRowArea` 負責。

## 修改的檔案
- `Sources/IdleVillagerApp/SessionPopoverView.swift`
  - `SessionPopoverView`：把 `.onDisappear { clearFailure() }` 換成 `.onChange(of: isVisible)`，只在 `isVisible` 由 true 變 false 時清除提示。
  - `SessionRowView`：移除 `onTapGesture`、`onHover`、`onDisappear`、`hasPushedCursor` 與 `setPointingHandCursor`，改用 `.overlay(ClickableRowArea(...))`。`popoverIsVisible` 變 false 時重設 `isHovered`，避免下次打開時某一列還停在反白。
  - 新增 `ClickableRowArea`（`NSViewRepresentable`）：以 cursor rect 顯示手指游標，以 tracking area 回報 hover，在滑鼠放開且仍在範圍內時觸發點擊。
- `CHANGELOG.md`：`[Unreleased]` 的 Fixed 補上兩項修正。
- `specs/popover-clear-failure.md`：規格與任務清單。

## 技術細節
- **失敗提示的驗證**：用 `performClick` 除錯碼開關清單，並在清單開著時切換到不存在的 Pane 製造失敗。修正前關閉清單後 `lastFailure` 仍存在，修正後為 nil。除錯碼沒有 commit。
- **手指游標為什麼原本不顯示**：攔截 `NSCursor.set()` 的呼叫來源後發現，手指游標設好之後，AppKit 內部的 `_NSTrackingAreaAKManager` 會一直把游標設回箭頭，角色動畫每次重畫畫面時也會觸發一次。AppKit 決定游標時，只採用滑鼠底下接收點擊的 view 的設定。用 SwiftUI 的 `onTapGesture` 時，接收點擊的是 SwiftUI 視窗本身，所以不論 `NSCursor.push()`，還是 `hitTest` 回傳 nil 的 cursor rect overlay，都會被蓋掉。
- **為什麼不用 `.pointerStyle(.link)`**：它需要 macOS 15，專案最低支援 macOS 14。
- **`ClickableRowArea` 的行為**：`acceptsFirstMouse` 回傳 true，清單視窗還不是 key window 時第一下點擊也有效。按下後移出範圍再放開視為取消，和一般按鈕一樣。滾輪事件沒有覆寫，會沿 responder chain 交給清單的捲動區。這個 view 不出現在輔助使用元素樹中，VoiceOver 的操作仍由 SwiftUI 的 `accessibilityAction` 處理。
- **使用者手動確認**：手指游標、hover 反白、移出時恢復箭頭、停在列上捲動、按下後拖出取消、點擊切換並關閉清單，都正確。
