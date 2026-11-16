# README 補上設定視窗的說明

- **分支:** `docs/readme-settings`
- **基底分支:** `main`
- **日期:** 2026-11-16

## 描述
在兩份 README 新增「Settings」段落，逐項說明設定視窗裡的 8 個選項，並各附一張設定視窗的截圖。

設定視窗目前有 8 個選項，分成「Menu Bar」「List & Alerts」「Appearance」三組，最上方還有一塊選單列預覽。README 只在「A few things I insist on」的條列裡提到 Language 一項，其他 7 個選項完全沒有說明，讀者也不知道設定視窗要從哪裡打開。

這次只動 `README.md`、`README.zh-TW.md`、`docs/images/` 與 `CHANGELOG.md`，不改 App 的程式邏輯。

## 已確認的決定

- **位置：** 新段落放在 Install 段落之後、What's new 段落之前。
- **寫法：** 依設定視窗的三個分組條列，每個選項一條，寫明作用與預設值。選項名稱用介面上實際顯示的文字：英文版用英文介面的名稱，中文版用繁體中文介面的名稱。
- **入口說明：** 段落開頭先講怎麼打開設定視窗（清單底部的「Settings…」按鈕，或清單開著時按 ⌘ 加逗號）。
- **截圖：** 中英文各一張。英文版 README 用英文介面的截圖，中文版用繁體中文介面的截圖。兩張都用預設值拍攝，系統外觀與現有的 `docs/images/popover.png` 一樣是深色。
- **原有的 Language 條列：** 「A few things I insist on」裡關於介面語言的那一條保留不動，它講的是「支援哪些語言」這個立場；新段落裡的 Language 條目只講怎麼切換。
- **CHANGELOG：** 在 `[Unreleased]` 的 `Changed` 加一筆，沿用前兩次 README 任務的做法。

## 各選項的行為（依程式碼核對）

以下內容是從 `Sources/IdleVillagerCore/Settings.swift`、`MenuBarSummary.swift`、`MenuBarCharacterMode.swift`、`ListOrder.swift`、`SessionListModel.swift`、`ApprovalAlert.swift` 與兩份 `Localizable.strings` 讀出來的，README 的文字以這裡為準。

| 分組 | 選項（英文介面／中文介面） | 預設值 |
| --- | --- | --- |
| Menu Bar／選單列 | Menu bar mode／選單列模式 | Counts／數量模式 |
| Menu Bar／選單列 | Always show categories with a count of 0／固定顯示數量為 0 的類別 | 關 |
| Menu Bar／選單列 | Show Done count／顯示完成小計數 | 關 |
| List & Alerts／清單與提醒 | Sort order／排序規則 | By priority／依優先度 |
| List & Alerts／清單與提醒 | Play character animations／播放角色動畫 | 開 |
| List & Alerts／清單與提醒 | Subtle alerts／低干擾提醒 | 開 |
| Appearance／外觀 | Language／語言 | English |
| Appearance／外觀 | Translucent list background／清單使用半透明背景 | 關 |

- **Menu bar mode：** 數量模式顯示圖示配數字。少量角色模式在已連線、Agent 有 1 到 3 個時，改成每個 Agent 畫一個不會動的角色，依優先度排列；4 個以上、沒有 Agent 或斷線時自動回到數量模式。
- **Always show categories with a count of 0：** 選單列固定的類別是 Working、Needs Approval、Idle。關閉時數量為 0 的類別不顯示，開啟後一律顯示。
- **Show Done count：** 關閉時 Done 不會有自己的數字，只和 Error、Unknown 一樣以尾端的小圓點 `•` 提示。開啟後在 Idle 後面多一個 `✓ n`。
- **Sort order：** 「依優先度」的順序是 Needs Approval、Error、Done、Working、Idle、Unknown，Workspace 與 Tab 也依內含的最高優先度排。「依 Workspace 名稱」讓 Workspace 與 Tab 依名稱排，同一個 Tab 裡的列仍依優先度。「固定順序」讓 Workspace、Tab、列都不因狀態改變而移動。
- **Play character animations：** 關閉後角色只畫靜止的姿勢，效果和系統的「減少動態效果」相同。
- **Subtle alerts：** 等待核准的 Agent 數量增加時，選單列強調 3 秒後恢復，沒有音效與系統通知。
- **Language：** English 或繁體中文，切換後立即生效。
- **Translucent list background：** 開啟後清單會透出模糊的桌面與後方視窗。系統開啟「降低透明度」時清單維持不透明。
- 所有設定存在 macOS 的使用者偏好（`UserDefaults`），重開 App 後保留。
- 設定視窗最上方的「Menu Bar Preview」用示範資料即時畫出選單列的樣子。

## 截圖的拍法

拍攝腳本在 `temp/readme-settings/`（`temp/` 不進 repo）。`shot.sh` 以示範模式（環境變數 `IDLEVILLAGER_DEMO=1`）另外啟動一份已安裝的 v0.3.3，打開清單再按下「Settings…」；`reshoot.sh` 等清單關閉後把設定視窗切成作用中的視窗再拍一次，開關才會是有顏色的樣子。

介面語言與各選項的值是用命令列參數暫時蓋過的（例如 `-language zh-Hant`），不會寫進使用者的偏好設定，所以截圖裡是預設值，而使用者自己的設定沒有被改動。唯一被寫入的是 macOS 自動記錄的設定視窗位置與大小。

## 任務清單

### 截圖
- [x] 以示範模式啟動 App，介面語言設成英文、其他選項用預設值，拍下設定視窗，存成 `docs/images/settings.png`
- [x] 同樣的做法把介面語言設成繁體中文再拍一張，存成 `docs/images/settings.zh-TW.png`
- [x] 檢查兩張截圖：內容是預設值、沒有拍到其他視窗或個人資訊

### 文案
- [x] 在 `README.md` 的 Install 段落後面新增「Settings」段落：入口說明、截圖、三組共 8 個選項
- [x] 在 `README.zh-TW.md` 新增對應的「設定」段落
- [x] 逐項比對兩份 README 的選項名稱與介面字串（`Localizable.strings`）完全一致
- [x] 在 `CHANGELOG.md` 的 `[Unreleased]` 加一筆變更紀錄
