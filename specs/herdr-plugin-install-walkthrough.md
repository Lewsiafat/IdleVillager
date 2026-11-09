# 把 Herdr plugin 移到 repo 根目錄並實測安裝 — Walkthrough

- **分支:** `feat/herdr-plugin-install`
- **基底分支:** `main`
- **日期:** 2026-11-09

## 變更摘要
整個 repo 現在就是一個 Herdr plugin，使用者執行 `herdr plugin install Lewsiafat/IdleVillager` 就能在自己的電腦上編出 `IdleVillager.app`，不會被 Gatekeeper 擋下。實測安裝、更新與移除的過程中，修正了「更新後同時跑兩個 App」與「每份安裝目錄佔 189 MB」兩個問題，並把結果寫進文件與 README。

## 修改的檔案
- `herdr-plugin.toml`（從 `distribution/herdr-plugin/` 移到 repo 根目錄）：plugin 根目錄改為整個 repo。`[[build]]` 以 `IDLEVILLAGER_CLEAN_BUILD=1` 執行 `distribution/make-app.sh`；`[[startup]]` 與 `launch` action 執行 `distribution/launch.sh`。
- `distribution/launch.sh`（從 `distribution/herdr-plugin/` 移入並改寫）：優先用 `HERDR_PLUGIN_ROOT` 找 App；啟動前結束其他路徑的 `IdleVillager.app`，同一路徑已在執行就不動作。
- `distribution/make-app.sh`：`IDLEVILLAGER_CLEAN_BUILD=1` 時，建置完刪除 `.build`。
- `distribution/herdr-plugin/build.sh`（刪除）：plugin 根目錄就是 repo，不需要另一層建置腳本。
- `README.md`：新增「安裝」一節，包含前置需求、安裝、立即啟動、更新、移除，以及選單列圖示被瀏海藏起來時的處理。
- `docs/08-distribution.md`：新增從 GitHub 安裝、更新、移除的實測結果，以及「瀏海遮住選單列圖示」的已知限制；更新後續任務清單。
- `specs/herdr-plugin-install.md`（新增）：任務規格。
- `specs/distribution-research.md`：勾掉上一個任務留下的 Popover 實測項目。

## 技術細節

**為什麼 manifest 放在根目錄。** Herdr 安裝時會把整個 repo checkout 到 `~/.config/herdr/plugins/github-installations/idlevillager-<hash>/<n>/checkout`，plugin 根目錄就是 manifest 所在的目錄。manifest 放在根目錄，`[[build]]` 就能直接用相對路徑呼叫 `distribution/make-app.sh`，不必假設子目錄與原始碼的相對位置。

**不會被 Gatekeeper 擋下的原因。** Herdr 用 git 下載原始碼，App 在使用者電腦上編譯，產物沒有 `com.apple.quarantine` 標記，只有不影響 Gatekeeper 的 `com.apple.provenance`。`spctl` 仍判定 `rejected`，但 Gatekeeper 只在檔案有 quarantine 標記時才檢查，實測啟動時沒有任何阻擋。

**更新後兩個實例的問題。** `herdr plugin update` 每次都 checkout 到新目錄並從頭編譯，舊版 App 仍在舊目錄執行。`open` 只沿用同一路徑的實例，所以會再開一個。`launch.sh` 改為先以 `pgrep` 找出所有 `IdleVillager.app/Contents/MacOS/IdleVillager`，結束路徑不同的實例（最多等 5 秒），全部處理完才決定是否啟動；中途不提早結束，避免漏掉排在後面的舊實例。

**建置快取。** 每次安裝都是全新 checkout，`.build` 不會被重用，刪掉後每份安裝目錄從 189 MB 降到約 3 MB。`[[build]]` 不會收到 Herdr 的執行期環境變數，所以用 `env IDLEVILLAGER_CLEAN_BUILD=1` 明確傳入，本機開發執行 `make-app.sh` 時不會刪快取。

**repo 公開。** Herdr 以 HTTPS 匿名 clone，私有 repo 安裝失敗。經使用者確認歷史中沒有金鑰或真實 Session 資料後，repo 改為公開。

**未驗證。** `[[startup]]` 需要重啟 Herdr server，會結束所有 Agent，沒有測；沒有 Xcode Command Line Tools 時的錯誤訊息也還沒測。`herdr plugin uninstall` 會保留安裝檔案且不結束 App，本次測試殘留已由使用者手動刪除。
