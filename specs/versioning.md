# 版號控管與 CHANGELOG、release note

- **分支:** `chore/versioning`
- **基底分支:** `main`
- **Worktree:** `/Users/lewis.chan/Documents/workspaceAI/IdleVillager-starter/.claude/worktrees/versioning`
- **日期:** 2026-11-09

## 描述
建立版號控管與發版機制。`herdr-plugin.toml` 的 `version` 是唯一版號來源，`make-app.sh` 從它讀取並寫入 App 的 `Info.plist`。新增 Keep a Changelog 格式的 `CHANGELOG.md`，目前所有內容放在 `[Unreleased]`；首個版本 0.1.0 由後續的 `/release` 發佈，屆時把 `herdr-plugin.toml` 改為 `0.1.0`、打 `v0.1.0` tag，並以該版 CHANGELOG 內容建立 GitHub Release。

本任務不在 App 內顯示版號。

## 任務清單
- [x] `make-app.sh` 從 `herdr-plugin.toml` 讀取版號，保留 `IDLEVILLAGER_VERSION` 覆寫
- [x] 新增 `CHANGELOG.md`，以 `[Unreleased]` 整理目前所有變更
- [x] 新增 `distribution/release-notes.sh <版號>`，從 CHANGELOG 擷取指定版本內容
- [x] 新增 `docs/09-release-process.md`：版號規則、發版步驟、Herdr 安裝與 tag 的關係
- [x] `CLAUDE.md` 寫明版號位置與發版文件，更新過時的「目前狀態」
- [x] `README.md` 更新過時的版本描述，文件導覽加入 `docs/09-release-process.md` 與 `CHANGELOG.md`
- [x] 驗證：`make-app.sh` 產出的 `Info.plist` 版號正確；`release-notes.sh` 對 Unreleased 與不存在的版本行為正確
