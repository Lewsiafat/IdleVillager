# README 補上設定視窗的說明 — Walkthrough

- **分支:** `docs/readme-settings`
- **日期:** 2026-11-16

## 變更摘要

兩份 README 新增「Settings／設定」段落，說明設定視窗怎麼打開，並逐項列出 8 個選項的作用與預設值，各附一張自己語言的設定視窗截圖。原本 README 只提到 Language 一個選項，其他 7 個完全沒有說明。這次沒有改 App 的程式邏輯。

## 修改的檔案

- `README.md`：在 Install 段落後面新增「Settings」段落。開頭說明入口（清單底部的 **Settings…**，或清單開著時按 ⌘ 加逗號），接著是截圖與「Menu Bar Preview」的說明，然後依「Menu Bar」「List & Alerts」「Appearance」三組條列 8 個選項。
- `README.zh-TW.md`：新增對應的「設定」段落，選項名稱用繁體中文介面的寫法。多了一句提醒：介面預設是英文，按鈕會寫 Settings…，要先切換語言才會看到中文名稱。
- `docs/images/settings.png`：英文介面的設定視窗截圖，840 × 1394 px，全部是預設值。
- `docs/images/settings.zh-TW.png`：繁體中文介面的設定視窗截圖，840 × 1342 px，全部是預設值。
- `CHANGELOG.md`：`[Unreleased]` 的 `Changed` 新增一筆。
- `specs/readme-settings.md`：這次任務的規格檔，內含依程式碼核對過的選項與預設值對照表。

## 技術細節

### 選項說明以程式碼為準

README 裡每個選項的行為與預設值，是從 `Settings.swift`、`MenuBarSummary.swift`、`MenuBarCharacterMode.swift`、`ListOrder.swift`、`SessionListModel.swift` 與 `ApprovalAlert.swift` 讀出來的，不是照介面上的文字推測。有三處介面上看不出來、要讀程式才知道：

- 「少量角色模式」只在已連線、Agent 有 1 到 3 個時才畫角色；4 個以上、沒有 Agent 或斷線時自動回到數量模式。README 只寫了「三個以內」與「四個以上」兩種情況。
- 「顯示完成小計數」關閉時，Done 並不是完全看不到，而是和 Error、Unknown 共用選單列尾端的小圓點。
- 「依 Workspace 名稱」只影響 Workspace 與 Tab 的順序，同一個 Tab 裡的列仍然依優先度排。

選項名稱用腳本比對過：兩份 README 的新段落裡，18 個介面字串（分組名稱、選項名稱、選單選項與入口按鈕）都和對應語言的 `Localizable.strings` 完全一致。

### 截圖的拍法

拍攝腳本在 `temp/readme-settings/`（`temp/` 不進 repo），共兩支腳本與兩支小工具：

- `shot.sh`：以示範模式（環境變數 `IDLEVILLAGER_DEMO=1`）另外啟動一份已安裝的 IdleVillager，透過 macOS 的輔助使用功能（System Events）按下選單列項目，再按清單底部的設定按鈕。
- `reshoot.sh`：把設定視窗切成作用中的視窗後再拍一次。
- `winid`：列出某個程序的視窗編號，交給 `screencapture -l` 只拍那一個視窗；加上 `-o` 不拍陰影。
- `activate`：用 `NSRunningApplication.activate` 把指定的 App 切到前景。

介面語言與各選項的值是用命令列參數暫時蓋過的，例如 `-language zh-Hant -showDoneCount x`。macOS 的使用者偏好會優先採用命令列參數，而且不會把它寫回去，所以截圖裡是預設值，使用者自己的四項偏好設定沒有被改動。`-AppleLanguages` 參數用來讓視窗標題列（由系統繪製）跟著同一個語言。唯一被寫入的是 macOS 自動記錄的設定視窗位置與大小。

### 拍攝時遇到的兩個問題

- **選到舊版 App。** 電腦上留著 9 個不同版本的安裝目錄（v0.1.0 到 v0.3.3）。腳本原本取清單的第一個，啟動的是 v0.2.0，那一版還沒有「外觀」區段，拍出來的視窗少了一組選項。現在腳本只挑版號和 `herdr-plugin.toml` 相同的那一份。
- **視窗拍成非作用中的灰色。** 設定視窗不是作用中的視窗時，打開的開關會畫成灰色，看不太出來是開還是關。System Events 的 `set frontmost` 對只出現在選單列的 App 沒有作用；剛按下設定按鈕時，選單列的清單還開著，設定視窗也不會成為作用中的視窗。實際可行的做法是分兩步：先用 `shot.sh` 打開設定視窗並保留那一份 App（`KEEP=1`），等幾秒讓清單關閉，再用 `reshoot.sh` 依序執行「System Events 把視窗提到最前面、`activate` 切到前景、再提一次」之後拍攝。把這些步驟合併在同一支腳本裡連續執行，拍出來仍然是灰色，原因沒有查明。

### 順帶觀察到、沒有處理的事

清單底部的「Settings…」與「Quit IdleVillager」兩個按鈕，透過 System Events 讀不到名稱（`name`、`title` 都是空的），腳本只能靠左右位置分辨哪一個是設定。這可能表示 VoiceOver 之類的輔助工具也讀不到按鈕名稱，但我沒有用 VoiceOver 實際確認，所以只記在這裡，沒有開 issue。

### 尚未確認

新段落與兩張截圖在 GitHub 上的顯示效果，要 push 之後才能確認。
