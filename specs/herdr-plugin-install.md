# 把 Herdr plugin 移到 repo 根目錄並實測安裝

- **分支:** `feat/herdr-plugin-install`
- **基底分支:** `main`
- **Worktree:** `/Users/lewis.chan/Documents/workspaceAI/IdleVillager-starter/.claude/worktrees/herdr-plugin-install`
- **日期:** 2026-11-09

## 描述
讓整個 repo 成為一個可以用 `herdr plugin install Lewsiafat/IdleVillager` 安裝的 Herdr plugin。安裝時由 `[[build]]` 在使用者電腦上把原始碼編成 `IdleVillager.app`，之後由 `[[startup]]` 與 `launch` action 啟動 App。

`herdr-plugin.toml` 放在 repo 根目錄，plugin 根目錄就是整個 repo，建置時不必猜原始碼的位置。實測方式是推送任務分支，再用 `herdr plugin install Lewsiafat/IdleVillager --ref feat/herdr-plugin-install` 安裝；main 在實測期間不變動。`[[startup]]` 需要重啟 Herdr server，會結束所有 Agent，這次不測。

## 任務清單

### 調整 plugin 結構
- [ ] `herdr-plugin.toml` 移到 repo 根目錄，`[[build]]` 改為 `sh distribution/make-app.sh`，`[[startup]]` 與 `[[actions]]` 改為 `sh distribution/launch.sh`
- [ ] `launch.sh` 移到 `distribution/launch.sh`，優先找 `$HERDR_PLUGIN_ROOT/dist/IdleVillager.app`
- [ ] 刪除 `distribution/herdr-plugin/`
- [ ] 本機用 `herdr plugin link` 確認新 manifest 沒有警告，測完 unlink

### 實測 `herdr plugin install`
- [ ] 推送任務分支，執行 `herdr plugin install Lewsiafat/IdleVillager --ref feat/herdr-plugin-install`
- [ ] 記錄：`[[build]]` 是否成功、耗時、安裝位置、build 的工作目錄與環境
- [ ] 用 `xattr -l` 檢查建置出來的 App 有沒有 quarantine 標記，並用 `spctl` 檢查
- [ ] 執行 `launch` action，確認 App 啟動
- [ ] 觀察 `herdr plugin update` 是否重新執行 `[[build]]`
- [ ] 測完 `herdr plugin uninstall`，確認沒有殘留

### 文件
- [ ] `README.md` 加入安裝說明（前置需求 Xcode Command Line Tools、安裝指令、移除方式）
- [ ] 更新 `docs/08-distribution.md` 的實測結果與後續任務
