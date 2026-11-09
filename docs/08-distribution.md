# 08 — 發佈方式研究

> 研究日期：2026-11-09。實測環境是 macOS 14.8.1、Apple Silicon、Herdr 0.9.5（protocol 22）、Swift 6.0.3（Command Line Tools）。
> 每一條結論都標明來源：「已實測」表示在上述環境實際執行過；「文件」表示只來自官方文件；「推論」表示由文件或程式碼推斷，尚未實際執行。

## 結論

建議分兩步發佈，兩步都不需要 Apple Developer Program 帳號：

1. **第一步：Herdr plugin，由原始碼在使用者電腦上建置。** 使用者執行 `herdr plugin install Lewsiafat/IdleVillager`，Herdr 會在安裝時執行 plugin 的建置指令，把 IdleVillager 編成 `.app`。之後每次 Herdr server 啟動，plugin 就用 macOS 的 `open` 指令開啟 App。在本機建置的 App 沒有 quarantine 標記，所以不會被 Gatekeeper 擋下，這是沒有簽章帳號時體驗最好的做法。代價是使用者必須先安裝 Xcode Command Line Tools，第一次安裝要等一到兩分鐘的編譯。
2. **第二步：GitHub Releases 提供預先建置好的 zip 檔，給不想編譯的人。** 這個 App 沒有簽章，下載後會被 Gatekeeper 擋下，使用者要到「系統設定」手動放行一次。說明文件必須寫清楚步驟。

不建議現階段使用 Homebrew Cask。Homebrew 5.0 起要求官方 Cask 必須簽章並通過 notarization，自建 tap 雖然還能安裝，但使用者仍然會被 Gatekeeper 擋下，而且 `--no-quarantine` 參數已經被移除，沒有比 zip 檔更方便。等之後申請 Developer 帳號、能做簽章和 notarization 時，再加上 Cask 與 DMG。

不建議使用 Herdr 桌面 App 的「mods」。mods 是另一個產品「Herdr 桌面 App」的 JavaScript 擴充，沒有公開規格，而目前的整合對象是 Herdr TUI。

原本有一個會讓打包後的 App 閃退的問題：SwiftPM 產生的 `Bundle.module` 在 `.app` 裡找不到資源。這個問題已在同一個分支修正，詳見「已修正：資源 bundle 查找」。

## 名詞說明

- **Gatekeeper**：macOS 的安全把關機制。檢查從網路下載的 App 是否由已登記的開發者簽章，並通過 Apple 的 notarization。
- **notarization（公證）**：開發者把 App 上傳給 Apple 自動掃描，通過後 Gatekeeper 才會直接放行。需要 Apple Developer Program 帳號，年費 99 美元。
- **quarantine 標記**：瀏覽器等程式下載檔案時，macOS 加在檔案上的延伸屬性 `com.apple.quarantine`。Gatekeeper 只檢查帶有這個標記的 App。
- **ad-hoc 簽章**：用 `codesign -s -` 做的本機簽章，不需要帳號。Apple Silicon 要求執行檔至少要有 ad-hoc 簽章才能執行，但 Gatekeeper 不認可它。
- **Herdr plugin**：一個含有 `herdr-plugin.toml` manifest 的目錄或 GitHub repo，Herdr TUI 會在特定時機執行裡面宣告的指令。

## 各路線比較

| 路線 | 需要帳號 | 使用者前置需求 | 會被 Gatekeeper 擋下 | 自動啟動 |
| --- | --- | --- | --- | --- |
| Herdr plugin（本機建置） | 否 | Herdr、Xcode CLT | 否（推論） | 是 |
| GitHub Releases zip（未簽章） | 否 | 無 | 是，要手動放行一次 | 否 |
| 自建 Homebrew tap 的 Cask（未簽章） | 否 | Homebrew | 是 | 否 |
| 簽章與 notarization 的 DMG 或 Cask | 是 | 無 | 否 | 否 |
| 由原始碼手動建置 | 否 | Xcode CLT、git | 否 | 否 |

Herdr plugin 也可以搭配下載好的 App 使用：plugin 的啟動腳本會依序在 `/Applications` 等位置尋找 `IdleVillager.app`。所以 plugin 不只是一種安裝方式，也是「Herdr 啟動時自動開 IdleVillager」的功能。

## Herdr plugin 路線

### 實測結果

manifest 是 repo 根目錄的 `herdr-plugin.toml`，啟動腳本是 `distribution/launch.sh`，建置腳本是 `distribution/make-app.sh`。整個 repo 就是 plugin 根目錄。

**本機 link（第一次研究時的原型，當時放在 `distribution/herdr-plugin/`）**

- **已實測**：Herdr 0.9.5 有 `herdr plugin` 指令，只是沒有列在 `herdr --help` 的指令清單裡。子指令有 `install`、`update`、`uninstall`、`link`、`unlink`、`enable`、`disable`、`list`、`action`、`log`、`pane` 等。
- **已實測**：`herdr plugin link <目錄>` 可以註冊本機的 plugin。manifest 指定 `platforms = ["macos"]` 與 `min_herdr_version = "0.9.5"` 時沒有任何警告；manifest 移到 repo 根目錄後再 link 一次，同樣沒有警告。
- **已實測**：`herdr plugin action invoke launch --plugin idlevillager` 會執行啟動腳本。腳本以 `open -g` 啟動 App，大約 0.1 秒結束，`herdr plugin log list --plugin idlevillager` 記錄了 exit code 與 stdout。
- **已實測**：由 `open` 啟動的 App，父程序是 launchd（PPID 為 1），不是 Herdr 的子程序。這符合官方文件「startup hook 是一次性指令，不是常駐的 daemon」的要求。
- **已實測**：App 已經在執行時再呼叫一次 action，`open` 會沿用既有的實例，不會開出第二個。
- **已實測**：`herdr plugin unlink` 之後 App 繼續執行，Herdr 不會結束它。
- **已實測**：從 `.app` 啟動的 App 有建立 unix socket 連線（fd 3）。macOS 不會顯示 client 端 socket 的路徑，所以無法確認連到的就是 `herdr.sock`，但應用程式只會連這一個 socket。

**從 GitHub 安裝（`herdr plugin install Lewsiafat/IdleVillager --ref feat/herdr-plugin-install --yes`）**

- **已實測**：私有 repo 無法安裝。Herdr 用 HTTPS 執行 git，沒有憑證時失敗並顯示 `could not read Username for 'https://github.com'`。repo 必須公開，使用者才裝得起來；repo 已在 2026-11-09 改為公開。
- **已實測**：安裝前 Herdr 會列出 plugin 的 id、來源、ref、commit，以及所有 build、startup、action 指令讓使用者確認；`--yes` 可以略過確認。
- **已實測**：安裝含建置共 83 秒，`[[build]]` 成功產生 `dist/IdleVillager.app`。這台電腦已有 Swift 6.0.3，沒有測「沒裝 Xcode Command Line Tools」的情況。
- **已實測**：Herdr 把整個 repo checkout 到 `~/.config/herdr/plugins/github-installations/idlevillager-<hash>/<n>/checkout`，plugin 根目錄就是這個 checkout。安裝後占用約 189 MB，其中 186 MB 是 `.build` 的建置快取。
- **已實測**：建置出來的 App 沒有 `com.apple.quarantine` 標記，只有 `com.apple.provenance`。後者是 macOS 13 起記錄「檔案由哪個程式產生」的標記，不會觸發 Gatekeeper。`spctl` 對這個 App 的評估仍是 `rejected`，但因為沒有 quarantine 標記，Gatekeeper 不會在開啟時檢查。
- **已實測**：`launch` action 從安裝目錄成功啟動 App，沒有出現任何 Gatekeeper 對話框。
- **已實測**：`herdr plugin log list` 只記錄 action 與 startup 的執行，不包含 `[[build]]` 的輸出。
- **已實測**：安裝後的 App 在沒有建置路徑的情況下（`.build` 已刪除，等同別人的電腦）正常顯示選單列與 Popover，使用者確認沒有閃退。這也驗證了 `ResourceBundleLocator` 的修正。

**更新與移除**

- **已實測**：`herdr plugin update idlevillager --yes` 會 checkout 到一個新的安裝目錄，再從頭執行 `[[build]]`，耗時約 81 秒，不會沿用舊目錄的建置快取。舊的安裝目錄不會立刻刪除。
- **已實測，已修正**：更新後舊版 App 仍在舊目錄執行。`open` 只會沿用同一路徑的實例，所以原本的 `launch.sh` 會再開一個新版，選單列出現兩個 IdleVillager。現在 `launch.sh` 會先結束其他路徑的 `IdleVillager.app`，同一路徑已在執行就不動作；三種情況（只有舊版、新舊都在、都沒有）都實測過。`swift run` 啟動的開發版不是 `.app`，不受影響。
- **已實測，已修正**：每份安裝目錄約 189 MB，其中 186 MB 是 `.build`。因為每次安裝都是全新 checkout，`[[build]]` 改為設定 `IDLEVILLAGER_CLEAN_BUILD=1`，建置完就刪掉 `.build`，每份安裝目錄降到約 3 MB。
- **已實測**：`herdr plugin uninstall idlevillager` 之後，Herdr 不再列出這個 plugin，但所有安裝目錄與空的 config 目錄都留在原處，正在執行的 App 也不會被結束。這和官方 CLI 文件「保留檔案讓執行中的 plugin 能結束」的說法一致；檔案何時清除沒有文件說明。README 的移除說明已提醒使用者自己結束 App。

**安裝後自動開啟**

- **已實測**：安裝完成後 App 不會出現。`[[startup]]` 只在 Herdr server 啟動時執行，install 與 update 都不會觸發，使用者裝完會以為沒裝好。
- **已修正，本機模擬**：`herdr-plugin.toml` 加上第二個 `[[build]]`，執行 `sh -c "sh distribution/launch.sh || true"`，建置完立即開啟 App；update 時 `launch.sh` 會結束舊版、開啟新版。在複製的 repo 中、不設定 `HERDR_PLUGIN_ROOT`，依序執行兩個 build 指令，確認 App 成功啟動、舊路徑的實例被結束、`.build` 被刪除；找不到 App 時第二步仍回傳 0，不會讓安裝失敗。
- **尚未實測**：透過 Herdr 實際執行（多個 `[[build]]` 是否依序執行、工作目錄是否為 plugin 根目錄）。merge 並推上 main 後，以 `herdr plugin update idlevillager` 驗證。
- 副作用：使用者刻意關掉 App 後執行 update，App 會被重新開啟。README 已說明。

**已知限制：瀏海遮住選單列圖示**

數量模式的選單列圖示寬約 96 pt。在有瀏海的 MacBook 上，選單列圖示太多時，macOS 會把最新加入的圖示藏起來，而且不會有任何提示。實測時開發版與 plugin 版同時執行，plugin 版的圖示就被藏起來了：系統回報它的位置在 x=849，`onScreen=false`。結束開發版後，plugin 版就出現了。README 應該提醒使用者：裝好後看不到圖示時，先移除其他選單列圖示騰出空間。

### 尚未驗證的部分

- **`[[startup]]` 自動啟動，尚未實測。** 根據文件，startup hook 只在 Herdr server 啟動，或 live handoff（Herdr 不中斷 Session 的換版機制）時執行，link、install 或 enable 時都不會執行。要測試就得重啟 Herdr server，但 `herdr server stop` 會連同所有 pane 裡的 Agent 一起結束，所以沒有測。可以等下次自然重開 Herdr 時觀察。
- **沒有 Xcode Command Line Tools 時的錯誤訊息，尚未實測。** `make-app.sh` 會在 `swift build` 失敗，安裝因此中止，但使用者實際看到的訊息還不知道。
- **官方文件沒有寫的事項**：各指令的逾時時間、server 停止時會不會結束 plugin 衍生的程序。

### 上架 Herdr plugin 列表

依官方文件，Herdr 的 plugin 列表沒有審核流程。只要 public repo 的預設分支有 `herdr-plugin.toml`，並在 GitHub 加上 `herdr-plugin` topic，列表大約 30 分鐘內就會更新。官方文件也提醒：Herdr 不審查、也不沙箱隔離 plugin 程式碼，使用者安裝前會看到確認提示。

### 前例

第三方專案 `herdr-remote` 的 Herdi.app 也是 macOS 選單列 App，同時提供 Herdr plugin 與 DMG 下載。這證明「選單列 App 加 Herdr plugin」的組合已有人在用，但我沒有逐一驗證它的實作細節。

## GitHub Releases 路線（未簽章）

### 打包成 `.app`

`distribution/make-app.sh` 會從 SwiftPM 的 release 建置產物組出 `IdleVillager.app`：

- `Contents/MacOS/IdleVillager`：執行檔。
- `Contents/Info.plist`：`CFBundleIdentifier` 設為 `io.github.lewsiafat.IdleVillager`，加上 `LSUIElement = true`，讓 App 不出現在 Dock。程式裡原本就有 `setActivationPolicy(.accessory)`，兩者並存沒有問題。
- `Contents/Resources/IdleVillager_IdleVillagerApp.bundle`：SwiftPM 的資源 bundle。
- 最後用 `codesign --force --deep -s -` 做 ad-hoc 簽章。

**已實測**：資源 bundle 放在 `.app` 根目錄時，codesign 會失敗並顯示 `unsealed contents present in the bundle root`，連 ad-hoc 簽章都過不了。改放 `Contents/Resources` 後，`codesign --verify --deep --strict` 就能通過。

### 使用者的放行步驟

**已實測**：`spctl -a -vv -t exec` 對 ad-hoc 簽章的 App 回報 `rejected`，代表下載後會被 Gatekeeper 擋下。

macOS 15（Sequoia）起，Control 點按或右鍵選「打開」已經無法繞過 Gatekeeper，使用者必須這樣做（文件與社群報導，未在 macOS 15 實測）：

1. 解壓縮後把 `IdleVillager.app` 拖進「應用程式」，然後打開一次，系統會顯示「已阻擋」。
2. 打開「系統設定」的「隱私權與安全性」，捲到「安全性」區塊，按「強制打開」（英文介面為 Open Anyway）。
3. 輸入管理者密碼，在確認對話框再按一次「強制打開」。之後就能正常開啟。

另一種做法是在終端機執行 `xattr -dr com.apple.quarantine /Applications/IdleVillager.app`，直接移除 quarantine 標記。說明文件可以同時列出兩種做法，但要提醒使用者：只有信任來源時才這麼做。

社群有回報指出，在 macOS 15.1，完全沒有簽章的 App 不會出現「強制打開」按鈕。我們的 App 有 ad-hoc 簽章，應該不受影響，但仍需要在 macOS 15 以上實測。

## Homebrew Cask 路線

- **社群報導**：Homebrew 5.0.0 起，官方 `homebrew/cask` 要求 App 必須簽章並通過 notarization，未通過的 Cask 在 2026 年 9 月起停用。
- **社群報導**：`--no-quarantine` 參數已被移除，所以透過 Cask 安裝的未簽章 App 同樣會被 Gatekeeper 擋下。
- 自建 tap（例如 `Lewsiafat/homebrew-tap`）還可以放 Cask，但體驗與 zip 檔相同，又多一個 repo 要維護。結論是等有簽章帳號後再做。

## 已修正：資源 bundle 查找

**問題。** SwiftPM 6.0.3 為 `IdleVillagerApp` 產生的 `resource_bundle_accessor.swift`，只在兩個位置尋找資源 bundle：`.app` 的根目錄，以及寫死在程式裡的本機建置路徑（例如 `.build/arm64-apple-macosx/release/IdleVillager_IdleVillagerApp.bundle`）。兩處都找不到時，程式會呼叫 `fatalError`。資源 bundle 放在 `.app` 根目錄又無法簽章，所以在沒有那條建置路徑的電腦上，只要 `BrandAssetCatalog` 一讀取品牌素材，App 就會閃退。觸發時機是 Popover 打開或少量角色模式畫角色的時候。這個結論是直接讀 `.build` 裡產生的原始碼確認的。

**修正。** 新增 `Sources/IdleVillagerCore/ResourceBundleLocator.swift`，依序在 `Contents/Resources`、`.app` 根目錄與執行檔所在目錄尋找資源 bundle，找不到時回傳 nil，不會 `fatalError`。執行檔所在目錄是給 `swift run` 開發時用的，那時資源 bundle 就在 `.build/debug` 裡。`BrandBodyView.swift` 的 `BrandAssetCatalog` 改用它；找不到資源 bundle 時，所有角色改畫 Generic 本體。`Sources` 裡已經沒有任何程式使用 `Bundle.module`。

**驗證。**

- **已實測**：`ResourceBundleLocatorTests` 的 6 個測試通過，涵蓋查找順序、`Contents/Resources` 優先、找不到時回傳 nil、同名一般檔案不算 bundle，以及 `swift run` 時的去重複。完整測試共 236 個，全部通過。
- **已實測**：資源 bundle 放在 `Contents/Resources` 的 `.app` 通過 `codesign --verify --deep --strict`。
- **尚未實測**：在 `.app` 裡打開 Popover 畫角色。這台電腦沒有開放「輔助使用」權限給終端機，沒辦法用 AppleScript 自動點開 Popover，需要手動確認。

## 後續任務

已完成：打包後 App 的 Popover 實測、把 manifest 移到 repo 根目錄、實測 `herdr plugin install`、README 安裝說明。

1. merge 進 main 後，在 GitHub repo 加上 `herdr-plugin` topic，上架 Herdr plugin 列表。
2. 下次重開 Herdr server 時，確認 `[[startup]]` 會自動開啟 App，並觀察舊安裝目錄會不會被清掉。
3. 在沒有 Xcode Command Line Tools 的電腦上測安裝，確認錯誤訊息看得懂；必要時讓 `make-app.sh` 先檢查 `swift` 是否存在，並印出安裝指引。
4. 在 macOS 15 以上實測未簽章 zip 的放行步驟。
5. 加上 GitHub Actions：打 tag 時自動執行 `make-app.sh`，並把 zip 上傳到 Releases。
6. 補上 App 圖示（`.icns`）。
7. 考慮縮短數量模式的選單列寬度，降低在瀏海機型上被藏起來的機會。
8. 之後若申請 Developer 帳號，再加上 Developer ID 簽章、notarization、DMG 與 Homebrew Cask。

## 參考來源

- Herdr plugin 文件：https://herdr.dev/tui/docs/plugins/
- Herdr plugin 上架方式：https://herdr.dev/tui/docs/marketplace/
- Herdr CLI 參考：https://herdr.dev/tui/docs/cli-reference/
- Herdr 安裝方式：https://herdr.dev/tui/docs/install/
- Herdr socket API：https://herdr.dev/tui/docs/socket-api/
- herdr-core：https://herdr.dev/core/
- GitHub topic `herdr-plugin`：https://github.com/topics/herdr-plugin
- herdr-remote（Herdi.app）：https://github.com/dcolinmorgan/herdr-remote
- Homebrew 5.0.0 對 Cask 簽章的要求：https://workbrew.com/blog/homebrew-5-0-0
- Homebrew 5.0.0 對企業環境的影響：https://workbrew.com/blog/what-homebrew-5-0-0-means-for-your-mac-fleet
- macOS Sequoia 的 Gatekeeper 變更：https://appleinsider.com/inside/macos-sequoia/tips/whats-changed-in-runtime-protection-for-macos-sequoia
- macOS 15.1 未簽章 App 的社群回報：https://www.osnews.com/story/141055/bug-or-intentional-macos-15-1-completely-removes-ability-to-launch-unsigned-applications/
