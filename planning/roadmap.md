# 開發路線圖

## P0：真實狀態與精準返回

目標：不做角色動畫，也能可靠掌握所有 Session，點一下回到指定 Herdr Pane。

- [ ] 確認 Herdr 安裝版本與 API／IPC 能力。
- [ ] 建立完整 Workspace / Tab / Pane / Agent 一覽。
- [ ] 驗證狀態正規化及數量一致性。
- [ ] 設計 macOS 選單列摘要與清單。
- [ ] 驗證跨 Tab / Pane / 視窗的聚焦切換。
- [ ] 處理斷線、未知狀態與重連。

完成條件：三項核心使用者需求全數通過。

## P1：活潑的小村民

- [ ] 取得可使用的官方 Logo 素材。
- [ ] 建立 Generic Agent 與共通道具圖層。
- [ ] 實現幹活、舉手、躺平、交工四種動作。
- [ ] 支援 Reduce Motion 與靜態備援。
- [ ] 實機確認多 Session 動畫效能。

完成條件：動畫與真實狀態一致、低干擾且無明顯效能問題。

## P2：細節設定

- [ ] 可切換「數量」與「少量角色」Menu Bar 模式。
- [ ] 可調整群組排序及是否隱藏 0 數量。
- [ ] 優化不同 macOS 外觀與字體大小。

完成條件：不增加操作負擔，維持簡潔。

## 發佈

研究結論見 `docs/08-distribution.md`。先做不需要 Apple Developer 帳號的方式。

- [x] 修正資源 bundle 查找，讓打包後的 `.app` 在別人的電腦上不會閃退。
- [ ] 以 Herdr plugin 發佈：安裝時由原始碼建置，Herdr 啟動時自動開啟 App。
- [ ] GitHub Releases 提供未簽章的 zip 檔，並附上 Gatekeeper 放行步驟。
- [ ] 申請 Developer 帳號後，再加上簽章、notarization、DMG 與 Homebrew Cask。

完成條件：沒用過這個專案的人，照 README 步驟能在 10 分鐘內裝好並看到選單列狀態。
