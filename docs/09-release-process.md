# 09 — 版號與發版流程

## 結論

IdleVillager 的版號只記在一個地方：repo 根目錄 `herdr-plugin.toml` 的 `version`。每次發版要做三件事：把 `CHANGELOG.md` 的 `[Unreleased]` 改成新版號、修改 `herdr-plugin.toml` 的 `version`、打 `vX.Y.Z` tag，並用該版的 CHANGELOG 內容建立 GitHub Release。日常開發時，任何使用者看得到的變更都要先記在 `[Unreleased]`。

## 版號放在哪裡

| 位置 | 用途 | 怎麼維護 |
| --- | --- | --- |
| `herdr-plugin.toml` 的 `version` | 唯一的版號來源；Herdr 顯示的 plugin 版本 | 發版時手動修改 |
| App 的 `Info.plist`（`CFBundleShortVersionString`、`CFBundleVersion`） | macOS 顯示的 App 版本 | `distribution/make-app.sh` 建置時自動從 `herdr-plugin.toml` 讀取 |
| git tag `vX.Y.Z` | 標記發版的 commit | 發版時建立 |
| `CHANGELOG.md` | 每個版本的變更紀錄 | 開發時寫進 `[Unreleased]`，發版時改成版號 |

`make-app.sh` 也接受環境變數 `IDLEVILLAGER_VERSION` 覆寫版號，只用於測試，發版時不要使用。

## 版號規則

依循 Semantic Versioning（語意化版本）：版號格式為 `主版號.次版號.修訂號`。

目前是 1.0 以前的階段，規則放寬如下：

- **次版號（0.X.0）**：新增功能，或有使用者需要注意的行為改變，例如設定項目改名、安裝方式改變。
- **修訂號（0.1.X）**：只修錯誤或改文件，使用者的操作方式不變。
- **1.0.0**：核心需求穩定、正式對外推廣時再升級。

## CHANGELOG 寫法

格式依循 Keep a Changelog。每個版本一個區段，依類別分組：

- `Added`：新功能。
- `Changed`：既有功能的改變。
- `Fixed`：錯誤修正。
- `Removed`：移除的功能。

每一條都從使用者的角度寫：寫「使用者會注意到什麼」，不寫內部的實作細節或 commit 標題。純內部重構、測試、規格文件不必列出。

## 發版步驟

建議使用 `/release` skill，它會依照下列步驟進行。手動發版時：

1. 確認在 `main` 分支，而且所有要發佈的變更都已經 merge。
2. 決定新版號，依上面的版號規則。
3. 修改 `CHANGELOG.md`：把 `## [Unreleased]` 底下的內容移到新的 `## [X.Y.Z] - YYYY-MM-DD` 區段，並留下一個空的 `## [Unreleased]`。
4. 把 `herdr-plugin.toml` 的 `version` 改成 `X.Y.Z`。
5. commit，然後建立 annotated tag：`git tag -a vX.Y.Z -m "IdleVillager X.Y.Z"`。
6. 推送：`git push && git push origin vX.Y.Z`。
7. 建立 GitHub Release，release note 由腳本從 CHANGELOG 擷取：

   ```sh
   distribution/release-notes.sh X.Y.Z > /tmp/idlevillager-release-notes.md
   gh release create vX.Y.Z --title "IdleVillager X.Y.Z" --notes-file /tmp/idlevillager-release-notes.md
   ```

   `release-notes.sh` 在找不到該版本或內容為空時會回傳錯誤，避免建立空白的 release。

## Herdr 安裝與版號的關係

`herdr plugin install Lewsiafat/IdleVillager` 與 `herdr plugin update` 安裝的是預設分支 `main` 的最新 commit，不是最新的 tag。所以 `main` 上任何 merge 都會在使用者下次更新時生效，即使還沒發版。

- 想讓使用者只裝到正式版，可以請他們用 `herdr plugin install Lewsiafat/IdleVillager --ref vX.Y.Z` 安裝。
- 這樣裝的版本不會跟著 `herdr plugin update` 前進到新版，Herdr 怎麼處理固定 ref 的更新尚未實測。
- 目前建議：`main` 只 merge 完成且測過的變更，讓 `main` 隨時都能安裝。
