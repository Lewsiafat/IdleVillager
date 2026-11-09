# 在 Popover footer 顯示 App 版號 — Walkthrough

- **分支:** `feat/show-app-version`
- **日期:** 2026-11-09

## 變更摘要
Popover footer 第二列的「設定…」與「結束 IdleVillager」中間，現在以小字顯示目前的 App 版號（例如 `v0.1.0`）；以 `swift run` 執行的開發版顯示「開發版」。

## 修改的檔案
- `Sources/IdleVillagerCore/AppVersionLabel.swift`（新增）：把 `CFBundleShortVersionString` 轉成顯示文字與無障礙文字。
- `Tests/IdleVillagerCoreTests/AppVersionLabelTests.swift`（新增）：5 個測試，涵蓋有版號、nil、空白、前後空白與無障礙文字。
- `Sources/IdleVillagerApp/SessionPopoverView.swift`：從 `Bundle.main` 讀取版號，放在 footer 第二列中間，使用 `.caption` 與 secondary 顏色並加上無障礙標籤。
- `CHANGELOG.md`：`[Unreleased]` 新增這項功能。
- `specs/show-app-version.md`（新增）：任務規格。

## 技術細節

**版號來源。** 執行時讀 `Bundle.main` 的 `CFBundleShortVersionString`。這個值由 `distribution/make-app.sh` 從 `herdr-plugin.toml` 寫進 `Info.plist`，所以發版時只要改 `herdr-plugin.toml`，畫面就會跟著變，不需要在程式裡寫死版號。

**開發版。** `swift run` 啟動的執行檔沒有 `Info.plist`，讀到 nil，顯示「開發版」，不會顯示錯誤或空白。

**邏輯放在 Core。** 依專案慣例，格式轉換放在 `IdleVillagerCore` 才能寫單元測試；畫面層只讀 `Bundle.main` 並排版。讀取結果存在 `static let`，App 執行期間版號不會改變，不必每次重繪都讀。

**驗證。** `swift test` 共 241 個測試通過。以 `make-app.sh` 打包，`Info.plist` 版號為 `0.1.0`；開啟後使用者確認 footer 中間顯示 `v0.1.0`，排版正常。確認後已換回使用者從 Herdr plugin 安裝的版本。
