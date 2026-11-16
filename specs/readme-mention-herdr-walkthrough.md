# README 開頭講明 IdleVillager 是 Herdr 的 plugin — Walkthrough

- **分支:** `docs/readme-mention-herdr`
- **日期:** 2026-11-16

## 變更摘要

README 開頭的標語現在直接說明 IdleVillager 是 Herdr 的 plugin，並附上 Herdr 官網的連結。原本讀者要讀到 Install 段落才知道必須先有 Herdr 才能用。中英文兩份 README 一起更新，沒有改 App 的程式邏輯。

## 修改的檔案

- `README.md`：標題下方的標語改成 `IdleVillager is a plugin for Herdr. It puts the state of every AI agent in Herdr on the macOS menu bar, where you can see it from any app.`，句中第一個 Herdr 連到 `https://herdr.dev`。
- `README.zh-TW.md`：標語改成「IdleVillager 是 Herdr 的 plugin，把 Herdr 裡每個 AI Agent 的狀態放上 macOS 選單列，切到哪個 App 都看得到。」，句中第一個 Herdr 連到 `https://herdr.dev`。
- `CHANGELOG.md`：`[Unreleased]` 的 `Changed` 新增一筆，記錄這次標語的調整。
- `specs/readme-mention-herdr.md`：這次任務的規格檔。

## 技術細節

### 連結用 `<a href>` 標籤

標語寫在置中的 HTML `<p align="center">` 區塊裡。GitHub 不會解析 HTML 區塊內的 Markdown 語法，`[Herdr](https://herdr.dev)` 寫在那裡會原樣顯示成文字，所以連結改用 `<a href="https://herdr.dev">Herdr</a>`。這和同一份 README 最上方的語言切換列用的是同一種寫法。

### 只連第一個 Herdr

標語那一句裡 Herdr 出現兩次，只有第一次加連結，第二次維持純文字。README 其他段落提到 Herdr 的地方都沒有動。

### 驗證範圍

`https://herdr.dev/` 在 2026-11-16 確認可以開啟（HTTP 200）。兩份 README 的修改是用 `git diff` 逐行核對的，沒有在 GitHub 上實際預覽過顯示效果。
