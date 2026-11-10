# 設定畫面新增語系切換，預設英文 — Walkthrough

- **分支:** `feat/language-switch`
- **日期:** 2026-11-11

## 變更摘要
設定視窗的「外觀」區段新增「語言」選項，可以在 English 與繁體中文之間切換。切換後選單列、Popover 與設定視窗立即換成新語言，重開 App 後保留。介面語言預設改為英文，不再跟隨 macOS 的偏好語言。

## 修改的檔案
- `Sources/IdleVillagerCore/Localization.swift`：`AppLanguage` 新增 `nativeName`，提供語言選單的選項名稱。`L10n` 移除 `useSystemLanguage()`，改成 `use(_:)`（設定整個程序的語言）與 `strings(for:)`（載入指定語言的字串表）。
- `Sources/IdleVillagerCore/Settings.swift`：`AppSettings` 新增 `language` 欄位，鍵為 `language`，預設 `.english`，儲存的值無法辨識時也回到英文。
- `Sources/IdleVillagerCore/L10nKey.swift` 與兩份 `Localizable.strings`：新增 `settings.appearance.language`（Language／語言）。
- `Sources/IdleVillagerApp/AppearanceSettingsSection.swift`：新增語言 Picker。
- `Sources/IdleVillagerApp/IdleVillagerMenuBarApp.swift`：啟動時依 `settings.language` 設定語言。Popover 與選單列標籤加上 `.id(settings.language)`。
- `Sources/IdleVillagerApp/SettingsView.swift`：設定表單加上 `.id(settings.language)`。
- `Tests/IdleVillagerCoreTests/AppSettingsTests.swift`：新增語言設定的預設值、重開後保留、無效值回到英文，以及改設定不影響整個程序語言的測試。
- `Tests/IdleVillagerCoreTests/LocalizationTests.swift`：新增 `strings(for:)` 與 `nativeName` 的測試。
- `CHANGELOG.md`：`[Unreleased]` 新增一項 Added 與一項 Changed。
- `README.md`、`README.zh-TW.md`、`docs/02-ui-ux-spec.md`、`docs/08-distribution.md`：改寫介面語言的說明，並記錄已知限制。

## 技術細節

**立即重繪的做法。** `L10n.text(...)` 讀的是全域字串表，SwiftUI 不會追蹤它，所以只換字串表的話，已經畫在畫面上的文字會停在舊語言。這次在 Popover、選單列標籤與設定表單的根 View 加上 `.id(settings.language)`：語言一改，SwiftUI 就把整棵 View 重建，所有文字重新從字串表取得。代價是 Popover 收合的 Tab、切回失敗的提示這類暫時狀態會被清掉。換語言是少見的操作，所以可以接受。

**切換的順序。** 語言 Picker 的 Binding 先呼叫 `L10n.use(_:)` 換掉字串表，再寫入 `settings.language`。重建畫面是由 `settings.language` 改變觸發的，所以重建時讀到的一定是新語言。

**設定與全域語言分開。** `AppSettings.language` 只負責儲存選擇，不會自己呼叫 `L10n.use(_:)`，套用語言是 App 層的工作。這樣 Core 的測試可以自由改語言設定，不會切換整個程序的語言，平行執行的測試也不會互相干擾。有一個測試專門確認這一點。

**已知限制。**
- 示範模式的 Tab 名稱、等待原因與來源名稱「示範資料」在 App 啟動時就建立好，換語言後要重開才會變。連 Herdr 時這些文字來自 Herdr，不受影響。
- 設定視窗標題列等 macOS 系統畫的文字依系統語言顯示，不受這個選項影響。

**保留未使用的程式碼。** `AppLanguage.resolve(preferredLanguages:)` 是原本跟隨系統語言的判斷邏輯，App 已經不再呼叫它，但它和測試都保留著，之後如果要加「跟隨系統」選項可以直接使用。

**驗證。** `swift build` 零警告，`swift test` 271 個測試全部通過。以 `make-app.sh` 打包成 `0.2.1-lang` 版後，在使用者環境連 Herdr 實機切換語言。
