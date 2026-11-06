# ADR 0001：以 Swift Package 建置專案，最低支援 macOS 14

- 狀態：已採用
- 日期：2026-11-04

## 背景

IdleVillager 是 SwiftUI 的 macOS 選單列工具，原本規劃建立 Xcode 專案。開發機目前只安裝 Command Line Tools（Swift 6.0.3），沒有 Xcode。實測 `swift build` 可以編譯 SwiftUI 與 `MenuBarExtra`，`swift test` 可以執行 Swift Testing。

架構文件把「最低 macOS 版本」列為待決策事項。`MenuBarExtra` 從 macOS 13 開始提供；`@Observable`（Observation framework）從 macOS 14 開始提供。開發機為 macOS 14.8。

## 決策

1. 專案以 Swift Package（`Package.swift`，swift-tools-version 6.0）建置，不建立 Xcode 專案。套件分成三個 target：
   - `IdleVillagerCore`：library，包含 Adapter protocol、資料型別、Session Store 與 Fake Adapter 等所有 model 層。
   - `IdleVillagerApp`：executable，SwiftUI `App` 與 `MenuBarExtra`，只依賴 Core。
   - `IdleVillagerCoreTests`：Swift Testing 測試，只連結 Core，不連結 App。
2. 最低支援版本為 macOS 14（`platforms: [.macOS(.v14)]`）。理由是 `MenuBarExtra` 需要 13 以上，而 Session Store 使用 macOS 14 才有的 `@Observable`；開發機本身就是 14.8，可以實機驗證。
3. 全專案採用 Swift 6 語言模式與嚴格並行檢查，`swift build` 與 `swift test` 必須零錯誤零警告。

## 後果

- 不需要 Xcode 即可開發、建置與測試，CI 也只需要 Swift toolchain。
- 執行檔沒有 `Info.plist`，因此不能用 `LSUIElement` 隱藏 Dock 圖示，改在啟動時呼叫 `NSApplication.setActivationPolicy(.accessory)`。
- 日後若要發佈為 `.app`（簽章、公證、App Icon、Bundle 顯示名稱），需要另外加入打包流程，例如補上 Xcode 專案或打包腳本。那時再另立決策紀錄。
- macOS 13 的使用者無法安裝。若之後需要支援 13，必須把 `@Observable` 改回 `ObservableObject`。
