# Changelog

IdleVillager 的所有重要變更都記錄在這個檔案。

格式依循 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)，版號依循 [Semantic Versioning](https://semver.org/lang/zh-TW/)。版號規則與發版步驟見 `docs/09-release-process.md`。

## [Unreleased]

### Added
- Popover 底部顯示目前的 App 版號（例如 `v0.1.0`）；以 `swift run` 執行的開發版顯示「開發版」。

## [0.1.0] - 2026-11-09

第一個可安裝的版本。

### Added
- 選單列狀態摘要：以數量顯示幹活中、等待核准、閒置等狀態，狀態圖示使用 SF Symbol，並可切換為「少量角色」模式。
- Popover 清單：依 Workspace、Tab、Pane 分組列出所有 Agent Session，點一下就切回對應的 Herdr Pane，並把終端機 App 帶到前景。
- 六種正規化狀態（Working、Needs Approval、Done、Idle、Error、Unknown）與計數規則；訊號不足時顯示 Unknown，Herdr 斷線時顯示斷線而不是零。
- Herdr socket adapter：透過 `~/.config/herdr/herdr.sock` 讀取 Session metadata，已在 Herdr 0.9.5 實機驗證。
- 角色與動畫：幹活、舉手、躺平、交工四種動作，支援 Reduce Motion 與靜態備援。
- 設定視窗：選單列模式、排序、是否顯示 0 數量與完成數、動畫開關、低干擾提醒，並附選單列即時預覽。
- IdleVillager 自有選單列標誌，取代看起來像實心圓的 Generic 村民。
- Herdr plugin：執行 `herdr plugin install Lewsiafat/IdleVillager` 即可在本機建置並安裝 App，不會被 Gatekeeper 擋下；安裝、更新完成與 Herdr server 啟動時會自動開啟 App。
- `distribution/make-app.sh`：把 SwiftPM 建置產物打包成 `IdleVillager.app`。
- 發佈方式研究文件 `docs/08-distribution.md`。

### Fixed
- Popover 最後一列被裁切：清單高度改依實際內容計算。
- 打包成 `.app` 後找不到資源 bundle 時會閃退：改用 `ResourceBundleLocator` 依序查找 `Contents/Resources` 等位置，找不到時改畫 Generic 角色。
- 更新 plugin 後同時出現兩個 App：啟動前會先結束其他路徑的舊版 App。

[Unreleased]: https://github.com/Lewsiafat/IdleVillager/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Lewsiafat/IdleVillager/releases/tag/v0.1.0
