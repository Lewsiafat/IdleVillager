# 在 Popover footer 顯示 App 版號

- **分支:** `feat/show-app-version`
- **基底分支:** `main`
- **日期:** 2026-11-09

## 描述
在 Popover footer 第二列中間，以小字顯示目前的 App 版號，例如 `v0.1.0`。版號在執行時從 `Bundle.main` 的 `CFBundleShortVersionString` 讀取，這個值由 `distribution/make-app.sh` 從 `herdr-plugin.toml` 寫入 `Info.plist`。以 `swift run` 執行的開發版沒有 `Info.plist`，顯示「開發版」。

格式轉換邏輯放在 `IdleVillagerCore` 的 `AppVersionLabel`，以單元測試驗證；畫面層只負責讀取 `Bundle.main` 與排版。

## 任務清單
- [x] 新增 `Sources/IdleVillagerCore/AppVersionLabel.swift`：有版號時顯示 `v<版號>`，nil 或空白時顯示「開發版」
- [x] 新增 `Tests/IdleVillagerCoreTests/AppVersionLabelTests.swift`
- [x] `SessionPopoverView` footer 第二列改為「設定…」、版號、「結束 IdleVillager」，版號用 `.caption` 與 secondary 顏色，並提供無障礙標籤
- [x] `swift test` 全數通過
- [x] 以 `make-app.sh` 打包後開啟，確認 footer 顯示 `v0.1.0`
- [x] `CHANGELOG.md` 的 `[Unreleased]` 加上這項變更
