# README 開頭講明 IdleVillager 是 Herdr 的 plugin

- **分支:** `docs/readme-mention-herdr`
- **基底分支:** `main`
- **日期:** 2026-11-16

## 描述
在 README 開頭的標語直接說明 IdleVillager 是 Herdr 的 plugin，並附上 Herdr 官網連結。

目前的標語只寫了「把 Herdr 裡每個 AI Agent 的狀態放上 macOS 選單列」，讀者要一路讀到 Install 段落才知道 IdleVillager 是以 Herdr plugin 的形式發佈、必須先有 Herdr 才能用。不認識 Herdr 的讀者在開頭也找不到任何連結可以了解它是什麼。

這次只動 `README.md` 與 `README.zh-TW.md` 標題下方的那一句標語，並在 `CHANGELOG.md` 記一筆，不改 README 的其他段落，也不改 App 的程式邏輯。

## 已確認的決定

- **改的位置：** 標題下方置中的標語第二句（粗體標語的下一行），不是圖片下方的第一段內文。
- **英文寫法：** `IdleVillager is a plugin for Herdr. It puts the state of every AI agent in Herdr on the macOS menu bar, where you can see it from any app.`
- **中文寫法：** `IdleVillager 是 Herdr 的 plugin，把 Herdr 裡每個 AI Agent 的狀態放上 macOS 選單列，切到哪個 App 都看得到。`
- **連結：** 句子裡第一次出現的 Herdr 連到 `https://herdr.dev`（2026-11-16 確認首頁可以開啟）。標語寫在 HTML 的 `<p>` 區塊裡，Markdown 的連結語法在那裡不會生效，所以要用 `<a href>` 標籤。
- **CHANGELOG：** 在 `[Unreleased]` 的 `Changed` 加一筆。上一次的 README 改寫（`docs/readme-refresh`）也有寫進 CHANGELOG，這次沿用同樣的做法。

## 任務清單
- [x] 修改 `README.md` 的標語，加入「plugin for Herdr」與官網連結
- [x] 修改 `README.zh-TW.md` 的標語，加入「Herdr 的 plugin」與官網連結
- [x] 確認兩份 README 的標語內容一致、連結網址正確
- [x] 在 `CHANGELOG.md` 的 `[Unreleased]` 加一筆變更紀錄
