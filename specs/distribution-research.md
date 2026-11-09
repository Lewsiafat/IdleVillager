# 發佈研究：IdleVillager 要怎麼發佈給其他人使用

- **分支:** `docs/distribution-research`
- **基底分支:** `main`
- **Worktree:** `/Users/lewis.chan/Documents/workspaceAI/IdleVillager-starter/.claude/worktrees/distribution-research`
- **日期:** 2026-11-09

## 描述
研究 IdleVillager 發佈給其他人使用的方式，評估「獨立 macOS App」與「Herdr plugin」兩條路線，並在本機實測 Herdr plugin 能不能啟動選單列 App。

已知前提：
- 目前 `Package.swift` 只產出 SwiftPM executable，還不是 `.app` bundle。
- 使用者目前沒有 Apple Developer Program 帳號，短期不付費。所以文件要以「未簽章」為主要情境，並寫清楚使用者要怎麼解除 Gatekeeper；簽章加 notarization 只當作未來選項。
- Herdr 0.9.5 有隱藏的 `herdr plugin` 指令（`install`、`link`、`action` 等）。官方文件說明 plugin v1 不支援原生的非終端 UI，但 `[[build]]`、`[[startup]]`、`[[actions]]` 可以執行任意 argv 指令。「由 plugin 啟動選單列 App」目前只是推論，尚未驗證。
- Herdr native app 的 mods 是給另一個產品（Herdr 桌面 App）用的，沒有公開規格，這次不評估。
- Herdr 授權為 Apache 2.0。

研究結論寫成 `docs/08-distribution.md`。實測用的最小 plugin 放在 `distribution/herdr-plugin/`，只在本機用 `herdr plugin link` 測試，不發佈到 GitHub topic。

## 任務清單

### 實測 Herdr plugin
- [x] 讀 `herdr plugin --help` 與官方 plugin 文件，確認 `herdr-plugin.toml` 必要欄位與 `[[build]]`、`[[startup]]`、`[[actions]]` 的實際行為
- [x] 寫最小 `herdr-plugin.toml`：`[[build]]` 執行 `swift build -c release`，`[[actions]]` 提供「啟動 IdleVillager」
- [ ] 測 `[[startup]]` 能不能在 Herdr 啟動時自動開 App（未測：重啟 Herdr server 會結束所有 Agent，改列為後續任務）
- [x] 用 `herdr plugin link` 在本機安裝並實測，記錄：build 的工作目錄與 log 位置、App 程序是否會被 Herdr 結束、重複啟動時會不會開出兩個實例
- [x] 實測完用 `herdr plugin unlink` 移除，不留在使用者環境

### 打包成 `.app`
- [x] 調查從 SwiftPM executable 包成 `.app` 的最小做法（`Info.plist`、`LSUIElement`、resources bundle 位置、ad-hoc 簽章 `codesign -s -`）
- [x] 確認未簽章 `.app` 從網路下載後的 Gatekeeper 行為，以及使用者解除的步驟（系統設定的「仍要打開」、`xattr -d com.apple.quarantine`）

### 撰寫研究文件
- [x] 寫 `docs/08-distribution.md`：先寫結論與建議路線，再寫各路線的流程、前提、限制與使用者安裝步驟
- [x] 比較各管道：GitHub Releases（zip 或 DMG）、Homebrew Cask（自建 tap）、Herdr plugin、由原始碼建置
- [x] 註明哪些結論已實測、哪些只是文件推論（遵守 CLAUDE.md「不得聲稱 Herdr API 已驗證」的規則）
- [x] 列出參考來源 URL
- [x] 視結論更新 `planning/roadmap.md` 與 `planning/open-questions.md`

### 修正資源 bundle 查找（使用者追加）
- [x] 新增 `ResourceBundleLocator`（Core），依序查 `Contents/Resources`、`.app` 根目錄、執行檔目錄，找不到回傳 nil
- [x] `BrandAssetCatalog` 改用 `ResourceBundleLocator`，移除 `Bundle.module` 的使用
- [x] 新增 `ResourceBundleLocatorTests`，完整測試通過
- [x] `make-app.sh` 把資源 bundle 放進 `Contents/Resources`，codesign 驗證通過
- [x] 手動打開打包後 App 的 Popover，確認不會閃退（在 `feat/herdr-plugin-install` 任務中，以刪除 `.build` 的 plugin 安裝版確認）
