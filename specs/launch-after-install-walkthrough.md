# 安裝或更新 plugin 後自動開啟 App — Walkthrough

- **分支:** `fix/launch-after-install`
- **基底分支:** `main`
- **日期:** 2026-11-09

## 變更摘要
`herdr plugin install` 與 `update` 完成後，IdleVillager 現在會自動開啟，不必等下次 Herdr server 啟動。做法是在 `herdr-plugin.toml` 加第二個 `[[build]]`，建置完立即執行 `distribution/launch.sh`。

## 修改的檔案
- `herdr-plugin.toml`：新增第二個 `[[build]]`，執行 `sh -c "sh distribution/launch.sh || true"`。
- `README.md`：說明安裝與更新完成後會自動開啟，以及「更新前關掉 App，更新後會再開啟」的副作用。
- `docs/08-distribution.md`：新增「安裝後自動開啟」一節，記錄問題、修正方式、本機模擬結果與尚未實測的部分。
- `specs/launch-after-install.md`（新增）：任務規格。

## 技術細節

**問題來源。** `[[startup]]` 只在 Herdr server 啟動或 live handoff 時執行，install 與 update 都不會觸發，所以使用者裝完看不到任何 App。

**為什麼放在 `[[build]]`。** `[[build]]` 是 install 與 update 都會執行、而且在使用者電腦上執行的唯一時機。build 階段沒有 `HERDR_PLUGIN_ROOT`，但 `launch.sh` 在沒有這個變數時本來就會以自己的位置推算 plugin 根目錄，所以不需要修改。`launch.sh` 會先結束其他路徑的 `IdleVillager.app`，update 後會直接換成新版。

**為什麼要 `|| true`。** 任何 `[[build]]` 失敗都會讓整個安裝中止。啟動 App 只是方便，不該讓已經建置成功的安裝失敗，所以用 `sh -c` 包起來並忽略失敗。

**驗證。** 使用者選擇不推送任務分支，所以以本機模擬為主：把 repo 複製到暫存目錄，不設定 `HERDR_PLUGIN_ROOT`，依序執行兩個 build 指令。結果是 App 成功啟動、原本執行中的正式版被結束、`.build` 被刪除；在沒有 `dist/` 的目錄執行第二步時，印出錯誤但回傳 0。模擬後已用 `launch` action 換回使用者的正式版。

**未驗證。** 透過 Herdr 實際執行時，多個 `[[build]]` 是否依序執行、工作目錄是否為 plugin 根目錄。要等 merge 並推上 main 後，以 `herdr plugin update idlevillager` 驗證。
