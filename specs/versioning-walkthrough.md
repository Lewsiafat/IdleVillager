# 版號控管與 CHANGELOG、release note — Walkthrough

- **分支:** `chore/versioning`
- **基底分支:** `main`
- **日期:** 2026-11-09

## 變更摘要
建立版號控管與發版機制：`herdr-plugin.toml` 的 `version` 成為唯一版號來源，App 建置時自動帶入；新增 `CHANGELOG.md`、擷取 release note 的腳本與發版流程文件。首個版本 0.1.0 尚未發佈，留給後續的 `/release`。

## 修改的檔案
- `CHANGELOG.md`（新增）：Keep a Changelog 格式，以 `[Unreleased]` 從使用者角度整理目前所有功能與修正。
- `distribution/release-notes.sh`（新增）：從 CHANGELOG 擷取指定版本的內容，供 `gh release create --notes-file` 使用；接受 `0.1.0` 或 `v0.1.0`，找不到或內容為空時回傳 1。
- `distribution/make-app.sh`：版號改從 `herdr-plugin.toml` 讀取，保留 `IDLEVILLAGER_VERSION` 覆寫；讀不到版號時中止。
- `docs/09-release-process.md`（新增）：版號位置、1.0 以前的版號規則、CHANGELOG 寫法、發版步驟，以及 Herdr 安裝的是 `main` 而不是 tag 的說明。
- `CLAUDE.md`：「目前狀態」改為實況（已有程式碼、以 Herdr plugin 發佈），新增「版號與發版」規則。
- `README.md`：開頭改為產品說明並連到 CHANGELOG；文件導覽與目錄結構加入 `docs/09-release-process.md` 與 `CHANGELOG.md`。
- `specs/versioning.md`（新增）：任務規格。

## 技術細節

**為什麼以 `herdr-plugin.toml` 為唯一來源。** Herdr 的 manifest 必須寫死 `version` 字串，無法引用其他檔案；反過來讓 `make-app.sh` 讀取 manifest，就只需要維護一個地方。讀取用 `sed` 比對行首的 `version = "..."`，不會誤抓 `min_herdr_version`。

**release note 擷取的邊界。** `release-notes.sh` 以 awk 從 `## [版號]` 開始，遇到下一個 `## [` 標題或檔尾的連結定義（`[0.1.0]: https://...`）就停止，再去掉頭尾空行。測試時發現最後一個版本會把連結定義一起抓進來，已修正並重測。

**驗證。** `make-app.sh` 產出的 `Info.plist` 版號為 manifest 的 `0.2.0`，設定 `IDLEVILLAGER_VERSION=9.8.7` 時為 `9.8.7`。`release-notes.sh` 以兩個版本加連結定義的假 CHANGELOG 測試：各版本只擷取自己的內容；空的 `[Unreleased]` 與不存在的版本都回傳 1。

**發 0.1.0 時要做的事。** 把 `[Unreleased]` 內容移到 `[0.1.0] - 日期`、`herdr-plugin.toml` 改為 `0.1.0`、打 `v0.1.0` annotated tag、推送，再用 `release-notes.sh 0.1.0` 建立 GitHub Release。
