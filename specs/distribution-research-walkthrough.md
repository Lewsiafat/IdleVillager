# 發佈研究：IdleVillager 要怎麼發佈給其他人使用 — Walkthrough

- **分支:** `docs/distribution-research`
- **基底分支:** `main`
- **日期:** 2026-11-09

## 變更摘要
研究 IdleVillager 的發佈方式，結論是以「Herdr plugin，安裝時在使用者電腦上由原始碼建置」為主、以「GitHub Releases 的未簽章 zip」為輔，兩者都不需要 Apple Developer 帳號。過程中發現打包後的 `.app` 會因為 SwiftPM 的 `Bundle.module` 找不到資源而閃退，已在同一個分支修正。

## 修改的檔案
- `docs/08-distribution.md`（新增）：發佈方式研究報告，包含結論、各路線比較、Herdr plugin 實測結果、Gatekeeper 放行步驟、資源 bundle 問題的修正說明與後續任務。每條結論都標明是已實測、文件或推論。
- `distribution/make-app.sh`（新增）：把 SwiftPM 的 release 建置產物組成 `IdleVillager.app`，寫入含 `LSUIElement` 的 `Info.plist`，資源 bundle 放在 `Contents/Resources`，最後做 ad-hoc 簽章。
- `distribution/herdr-plugin/herdr-plugin.toml`、`launch.sh`、`build.sh`（新增）：Herdr plugin 原型。`launch.sh` 依序尋找 `IdleVillager.app` 並用 `open -g` 啟動；`build.sh` 在 `herdr plugin install` 時呼叫 `make-app.sh`。
- `Sources/IdleVillagerCore/ResourceBundleLocator.swift`（新增）：取代 `Bundle.module` 的資源 bundle 查找，找不到時回傳 nil。
- `Sources/IdleVillagerApp/BrandBodyView.swift`：`BrandAssetCatalog` 改用 `ResourceBundleLocator`，不再使用 `Bundle.module`。
- `Tests/IdleVillagerCoreTests/ResourceBundleLocatorTests.swift`（新增）：6 個測試，涵蓋查找順序、找不到時回傳 nil、同名一般檔案與 `swift run` 去重複。
- `README.md`：文件索引與目錄結構加入 `docs/08-distribution.md`。
- `planning/roadmap.md`：新增「發佈」階段。
- `planning/open-questions.md`：新增「發佈」待確認事項。
- `.gitignore`：忽略打包輸出目錄 `dist/`。
- `specs/distribution-research.md`（新增）：任務規格。

## 技術細節

**Herdr plugin 的實測結果。** Herdr 0.9.5 有 `herdr plugin` 指令，只是沒有列在主要 help 裡。用 `herdr plugin link` 掛上原型後，`herdr plugin action invoke` 能成功啟動 App。App 的父程序是 launchd，不是 Herdr 的子程序；重複呼叫不會開出第二個實例；`unlink` 之後 App 繼續執行。測完已經 unlink，並刪除 Herdr 留下的空設定目錄。`[[startup]]` 需要重啟 Herdr server 才會觸發，而重啟會結束所有 Agent，所以沒有測；`[[build]]` 只在從 GitHub 安裝時執行，也還沒測。

**為什麼主推 plugin 的本機建置。** 在使用者電腦上編出來的 App 沒有 quarantine 標記，Gatekeeper 不會檢查，所以不需要簽章也能直接開。這點目前是推論，要等實際 `herdr plugin install` 後用 `xattr -l` 確認。下載的未簽章 App 會被 `spctl` 判定為 `rejected`，這點已實測。

**資源 bundle 問題。** SwiftPM 產生的 `Bundle.module` 只查 `.app` 根目錄和寫死的本機建置路徑，找不到就 `fatalError`。資源 bundle 放在 `.app` 根目錄時，codesign 會失敗（`unsealed contents present in the bundle root`），所以必須放在 `Contents/Resources`，而 `Bundle.module` 不查那裡。`ResourceBundleLocator` 依序查 `Contents/Resources`、`.app` 根目錄與執行檔目錄。比對候選目錄時用 path 字串，因為 `deletingLastPathComponent()` 產生的 URL 帶結尾斜線，直接比較 URL 會被當成不同的目錄。

**驗證狀態。** 完整測試 236 個全部通過；重新打包的 `.app` 通過 `codesign --verify --deep --strict`。還沒確認的是在打包後的 App 裡手動打開 Popover，因為終端機沒有輔助使用權限，無法自動點開。
