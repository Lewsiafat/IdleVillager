# 設定畫面新增語系切換，預設英文

- **分支:** `feat/language-switch`
- **日期:** 2026-11-10

## 描述

在設定畫面新增「語言」選項，讓使用者在 English 與繁體中文之間切換，切換後選單列、Popover 與設定畫面立即換成新語言。

使用者從未設定過語言時，一律使用英文，不再跟隨 macOS 的偏好語言。這取代目前啟動時呼叫 `L10n.useSystemLanguage()` 的行為。

### 技術方案

1. **偏好設定**：`AppSettings` 新增 `language: AppLanguage` 欄位，鍵為 `language`，預設 `.english`。儲存的值無法辨識時也回到英文。
2. **切換語言**：`L10n` 新增 `use(_ language: AppLanguage)`，載入對應字串表並設為整個程序的語言。App 啟動時與 `language` 改變時都呼叫它。
3. **立即重繪**：`L10n.text(...)` 本身不會被 SwiftUI 追蹤。做法是在 Popover、選單列標籤、設定畫面的根 View 讀取 `settings.language`，並加上 `.id(settings.language)`，語言一改就整棵重建，畫面上所有文字重新從字串表取得。
4. **建立當下就寫死的文字**：有些文字在物件建立時就取好，例如示範資料的 Tab 名稱（`DemoSnapshot`），切換後不會自動更新。實作時逐一檢查，能改成顯示時才取字串的就改，改不了的在 walkthrough 記錄下來。
5. **選項名稱的寫法**：選單裡的語言名稱固定用該語言本身書寫（English、繁體中文），不隨目前的介面語言翻譯，讓看不懂目前語言的人也找得到自己的語言。

### 不在範圍內

- macOS 系統提供的文字（例如設定視窗的標題列、系統選單）由系統語言決定，不受這個設定影響。
- 不新增其他語言。

## 任務清單
- [x] `L10n` 新增 `use(_:)`，移除或保留 `useSystemLanguage()`（App 不再呼叫）
- [x] `AppSettings` 新增 `language`（預設 `.english`），含讀回與寫入
- [x] `L10nKey` 與兩份 `Localizable.strings` 新增設定項目文字（語言標題、可選的說明）
- [x] 設定畫面新增語言 Picker，選項顯示 English 與繁體中文
- [x] App 啟動時依 `settings.language` 設定語言，取代 `L10n.useSystemLanguage()`
- [x] 語言改變時呼叫 `L10n.use(_:)`，並讓 Popover、選單列、設定畫面立即重繪
- [x] 檢查建立當下就寫死文字的地方（`DemoSnapshot`、Adapter 來源名稱等），切換後能更新或記錄限制（只影響示範模式，已記錄在 `docs/02-ui-ux-spec.md` 第 6 節）
- [x] 測試：`AppSettings.language` 預設值、讀回、無效值；`L10n.use(_:)` 切換結果
- [x] 實機確認：`IDLEVILLAGER_DEMO=1 swift run IdleVillagerApp` 下切換語言，Popover 開著與關閉時都會更新
- [x] 更新 `CHANGELOG.md` 的 `[Unreleased]`
- [x] 更新文件：`README.md` 與 `README.zh-TW.md` 第 21 行、`docs/02-ui-ux-spec.md` 第 6 節（原本寫「不提供 App 內的語言切換」）
