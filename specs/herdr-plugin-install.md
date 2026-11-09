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
- [x] `herdr-plugin.toml` 移到 repo 根目錄，`[[build]]` 改為 `sh distribution/make-app.sh`，`[[startup]]` 與 `[[actions]]` 改為 `sh distribution/launch.sh`
- [x] `launch.sh` 移到 `distribution/launch.sh`，優先找 `$HERDR_PLUGIN_ROOT/dist/IdleVillager.app`
- [x] 刪除 `distribution/herdr-plugin/`
- [x] 本機用 `herdr plugin link` 確認新 manifest 沒有警告，測完 unlink

### 實測 `herdr plugin install`
- [x] 推送任務分支，執行 `herdr plugin install Lewsiafat/IdleVillager --ref feat/herdr-plugin-install`（私有 repo 裝不起來，經使用者同意把 repo 改為公開）
- [x] 記錄：`[[build]]` 是否成功、耗時、安裝位置、build 的工作目錄與環境
- [x] 用 `xattr -l` 檢查建置出來的 App 有沒有 quarantine 標記，並用 `spctl` 檢查
- [x] 執行 `launch` action，確認 App 啟動
- [x] 觀察 `herdr plugin update` 是否重新執行 `[[build]]`
- [x] 測完 `herdr plugin uninstall`，確認沒有殘留（結果：Herdr 保留所有安裝檔案；刪除殘留的指令被權限擋下，交由使用者執行）

### 實測中發現並修正（追加）
- [x] 更新後會同時跑兩個 App：`launch.sh` 先結束其他路徑的 `IdleVillager.app` 再啟動
- [x] 每份安裝目錄約 189 MB：`[[build]]` 設定 `IDLEVILLAGER_CLEAN_BUILD=1`，建置完刪除 `.build`
- [x] 在沒有建置路徑的安裝目錄執行 App，使用者確認 Popover 正常、沒有閃退

### 文件
- [x] `README.md` 加入安裝說明（前置需求 Xcode Command Line Tools、安裝指令、移除方式、選單列圖示被瀏海藏起來時的處理）
- [x] 更新 `docs/08-distribution.md` 的實測結果、已知限制與後續任務
