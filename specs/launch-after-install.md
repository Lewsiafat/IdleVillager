# 安裝或更新 plugin 後自動開啟 App

- **分支:** `fix/launch-after-install`
- **基底分支:** `main`
- **Worktree:** `/Users/lewis.chan/Documents/workspaceAI/IdleVillager-starter/.claude/worktrees/launch-after-install`
- **日期:** 2026-11-09

## 描述
`herdr plugin install` 完成後 App 不會出現，因為 `[[startup]]` 只在 Herdr server 啟動時執行。使用者裝完會以為沒裝好。

做法：在 `herdr-plugin.toml` 加第二個 `[[build]]`，建置完立即執行 `distribution/launch.sh`。build 階段沒有 `HERDR_PLUGIN_ROOT`，`launch.sh` 會用自己的位置推算 plugin 根目錄。指令以 `sh -c "... || true"` 包起來，啟動失敗不會讓安裝失敗。update 時 `launch.sh` 會結束舊路徑的實例，直接換成新版。

使用者選擇不推送任務分支，所以實測以本機模擬為主；透過 Herdr 的實測等 merge 並推上 main 後，用 `herdr plugin update` 進行。

## 任務清單
- [x] `herdr-plugin.toml` 加上第二個 `[[build]]`，建置完執行 `launch.sh`
- [x] 本機模擬兩個 build 步驟：App 啟動、舊實例被結束、`.build` 被刪除
- [x] 模擬找不到 App 的情況，確認第二步回傳 0
- [x] 模擬後把使用者的正式版 App 換回來
- [x] README 說明安裝與更新後會自動開啟
- [x] 更新 `docs/08-distribution.md`
- [ ] merge 並推上 main 後，以 `herdr plugin update idlevillager` 實測
