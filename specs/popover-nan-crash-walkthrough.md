# 狀態改變時 App 當掉（height is NaN，issue #55）— Walkthrough

- **分支:** `fix/popover-nan-crash`
- **日期:** 2026-11-14

## 變更摘要

修好 issue #55：清單打開過之後，只要有 Agent 的狀態改變，而且這次轉換沒有過渡動畫，App 就可能以 `Invalid view geometry: height is NaN` 當掉。原因是沒有過渡時仍播放一段長度為 0 秒的 keyframe 動畫，SwiftUI 算出 NaN 的位移。現在沒有過渡時改用 0.001 秒、不跳也不淡入的參數，並加上「過渡長度必須大於 0」的測試。

## 修改的檔案

- `Sources/IdleVillagerApp/CharacterMotionModifiers.swift`：`CharacterTransitionModifier` 在 `transition` 為 nil 時改用 `noTransition` 參數（長度 0.001 秒），不再用長度 0。註解說明為什麼不能用 0，也說明為什麼不能改成不套 `keyframeAnimator`。
- `Tests/IdleVillagerCoreTests/CharacterMotionTests.swift`：新增 `CharacterTransitionParametersTests`，檢查所有 `CharacterTransition` 的 `duration` 都大於 0。
- `CHANGELOG.md`：`[Unreleased]` 新增這項修正。

## 技術細節

### 根本原因

`CharacterTransitionModifier` 對每個角色都套用 `keyframeAnimator`，trigger 是角色狀態，所以任何狀態改變都會播放一次。沒有過渡的轉換（動畫關閉、系統 Reduce Motion，或 Working 轉 Needs Approval 這類本來就不跳的轉換）原本用長度 0 的 keyframe 當作「不播放」。SwiftUI 用「經過時間 ÷ 總長度」算進度，總長度為 0 時得到 NaN，角色的 `offset` 與 `opacity` 跟著變成 NaN。角色裡的 SF Symbol 圖層是 AppKit 的 `_NSGraphicsView`，它收到高度為 NaN 的 frame 後，AppKit 在 `-[NSView setFrame:]` 檢查失敗，直接中止程式。

觸發條件是「清單的 view tree 建立過」之後發生狀態改變，清單開著或關著都會當。所以正式版會在啟動後幾分鐘、不一定在點清單的當下消失。這個問題從 2026-11-04 的 `c34adbb` 就存在，不是 #56 或 #57 引入的。v0.3.1 的原始碼放進同一個 loop 也會當。v0.3.2 在正式環境當得特別頻繁，原因沒有查明。

### 被否定的假設

- `CharacterView` 的 `.geometryGroup()`：拿掉後仍然當。
- `listContentHeight` 量到 NaN：NaN 出現在角色內 8.5 pt 寬的 SF Symbol 圖層，不在清單層級。
- #56 的 `LoopingHostingView` 或 #57 的 `ClickableRowArea`：v0.3.1 一樣會當。
- 只有真實滑鼠點擊才會觸發：自動化第 1 輪就重現。

### 為什麼不改成「沒有過渡就不套 animator」

這樣寫也能避開 NaN，但 view 結構會隨過渡有無而切換。`keyframeAnimator` 只在 trigger 改變時播放，剛插入畫面時不播放。Working 轉 Done 的當下正好從「沒套」切到「有套」，慶祝跳躍就不會出現。保留同一個 animator、只把長度改成很短的非零值，可以避免這個問題。

### 驗證方式

除錯碼備份在 `temp/debug55/`：`Debug55.swift` 攔截 `-[NSView setFrame:]`，遇到 NaN 時印出 view 類別與上層鏈；`menubar-app-hook.patch` 用示範資料自動開關清單並改變狀態。重跑方法：

1. `cp temp/debug55/Debug55.swift Sources/IdleVillagerApp/`
2. `git apply temp/debug55/menubar-app-hook.patch`
3. `swift build`
4. `temp/run-nan-loop.sh <true|false> [輪數] [states|closed|rows|toggle|all]`。紅燈是 process 以 SIGTRAP 結束（exit 133）或 log 出現 NaN frame。
5. 測完執行 `git apply -R temp/debug55/menubar-app-hook.patch`，並刪除 `Sources/IdleVillagerApp/Debug55.swift`。

結果：

- 長度改回 0 時，最小重現（只把一個 Session 從 Working 改成 Needs Approval）第 1 輪就當。
- 修正後，動畫開與關各跑 `states`、`closed`、`all` 三種模式，每種 30 輪，全部綠燈。
- `swift test` 283 個測試全過。
- 使用者用真實 Herdr 目視確認：動畫外觀不變，Working 轉 Done 有跳躍，Working 轉 Needs Approval 和動畫關閉時都沒有當掉。

### 測試的限制

真正出錯的路徑在 App 層的 SwiftUI view，專案沒有 App 層的測試 target，所以沒有測試能直接鎖住「沒有過渡時不能用長度 0」。Core 的新測試只保證「有過渡時長度大於 0」。App 層的回歸要靠上面的 loop。
