# IdleVillager 詞彙表

本專案程式碼、測試與文件共用的核心詞彙。命名型別與測試時請使用這裡的詞。

## 來源階層

- **Workspace**：Herdr 中最上層的工作區，底下包含一個或多個 Tab。以來源提供的穩定 `WorkspaceID` 識別。
- **Tab**：Workspace 底下的分頁，底下包含一個或多個 Pane。以 `TabID` 識別，同名 Tab 仍以 ID 區分。
- **Pane**：Tab 內的一個分割窗格，是 Focus 的最終目標。以 `PaneID` 識別，`paneLabel` 只用於顯示。
- **Agent Session**：在某個 Pane 裡執行的一個 AI Agent 實例（例如一個 Claude Code Session），也是所有計數的單位。以 `AgentSessionID` 識別，它是 Session Store 的主鍵。

## 正規化狀態

每個 Agent Session 在任一時刻恰好屬於下列六種之一。

- **Working**：Agent 正在執行任務，或有可靠的進行中訊號。
- **Needs Approval**：Agent 在等人核准、回答或給權限，優先於 Idle。
- **Done**：任務已完成，可能還沒被查看；Done 不等於 Idle。
- **Idle**：Session 存在但沒有活躍任務，只能由明確事件推導，不能由 CPU 低或久未輸出推導。
- **Error**：已確認任務失敗或異常。
- **Unknown**：訊號不足、無法對應或訊號互相衝突時的狀態，必須明確顯示而不是被隱藏。

- **State Normalizer**：把 Adapter 給的 `rawState` 與 `stateSource` 轉成上述六種狀態之一的純函式（`StateNormalizer`）。只有明確事件能得到非 Unknown 的狀態；`rawState` 的對應表只定義在 `StateNormalizer.rawStateTable` 一處。
- **衝突描述（Conflict Note）**：一個 Session 同時帶有多個互斥訊號（`rawState` 以 `|` 分隔，例如 `working|idle`）時，該 Session 為 Unknown，並附上只含正規化狀態名稱的說明（例如「訊號衝突：Working、Idle」），不含任何來源原始文字。Needs Approval 與 Idle 同時出現不算衝突，結果為 Needs Approval。

## 選單列摘要

- **Menu Bar Summary**：由 Store 的計數與連線狀態推導出的純值摘要模型（`MenuBarSummary`），再由 `MenuBarSummaryFormatter` 轉成選單列文字，例如 `⚒ 3  ✋ 2  💤 1`。文字不含任何 Session 名稱。
- **摘要模式（Summary Mode）**：`normal`（顯示數量）、`disconnected`（斷線或重連中，只顯示斷線表示，不含任何數字）、`zeroAgents`（已連線但沒有 Agent Session，顯示「0 個 Agent」）。
- **隱藏狀態提示（Hidden States）**：Done、Error、Unknown 不在選單列預設數量中；任一大於 0 時摘要模型的 `hasHiddenStates` 為 true，選單列尾端加上小標記 `•`。開啟 Done 小計數後，Done 不再算作隱藏狀態，Error 與 Unknown 仍然算。
- **Done 小計數（Done Count）**：設定開啟後，選單列在 Idle 之後多顯示 `✓ n`，例如 `⚒ 3  ✋ 2  💤 1  ✓ 2`；數量為 0 時與其他類別一樣依「固定顯示 0 數量」決定是否顯示。

## 設定

- **App Settings**：使用者偏好設定的可觀察模型（`AppSettings`），包含「固定顯示 0 數量」（`alwaysShowZeroCounts`）、「顯示 Done 小計數」（`showDoneCount`），以及預留但尚未接上行為的選單列模式（`menuBarMode`）、排序規則（`sortRule`）、動畫開關（`animationsEnabled`）、低干擾提醒（`lowDistractionAlerts`）。摘要模型只透過 `MenuBarSummary(snapshot:settings:)` 接收設定值，不自行讀取偏好儲存。
- **Settings Store**：設定的鍵值儲存介面（`SettingsStore`）。正式環境用 `UserDefaultsSettingsStore`（macOS 標準使用者偏好），測試用 `InMemorySettingsStore`；設定改動即時寫入，`AppSettings` 初始化時從中讀回，因此重啟後保留。

## Popover 清單

- **Session List Model**：由 Store snapshot 推導出的 Popover 純值清單模型（`SessionListModel`），包含固定標題 `IdleVillager`、Agent 總數、Workspace → Tab → 列的三層群組，以及底部資訊區。畫面只渲染它，不自行推論狀態或排序。
- **列（Row）**：清單中代表一個 Agent Session 的一列，以 `agentSessionID` 為 id，帶有 agentKind、displayName、paneLabel、正規化狀態、狀態圖示（⚒ ✋ ✓ 💤 ! ?）、狀態短文字（幹活中、等核准、完成、閒置、錯誤、訊號不足）與可選的補充說明（`detail`，目前是衝突描述）。
- **清單優先度（Priority Order）**：Needs Approval > Error > Done > Working > Idle > Unknown。列依此排序；Tab 與 Workspace 群組依內含的最高優先度（`topState`）排序，所以急件所在的群組會浮到最上方。同優先度時依名稱（數字以數值比較）再依 ID 排序。
- **底部資訊區（Footer）**：Popover 底部的來源與連線資訊，包含來源名稱 Herdr、連線狀態文字與最後成功更新時間。Herdr 只出現在這裡，不出現在標題。
- **Tab 收合**：使用者可收合 Tab 群組。收合狀態只存在 App 的 `SessionPopoverViewModel`，不在純值模型中，重啟後不保留。

## 其他

- **isStale**：表示某個 Session 的資料已經不新鮮的旗標；自上次成功更新超過門檻，或 Adapter 回報斷線時為 true。
- **Focus**：使用者點擊一列後，把 Herdr 對應視窗帶到前景並聚焦到指定 Pane 的動作；結果是成功，或帶明確原因的失敗。
- **Focus Coordinator**：處理 Focus 流程的可觀察物件（`FocusCoordinator`）。以列的 `AgentSessionID` 與 `PaneID`（不用清單索引）先向 Session Store 的 snapshot 確認目標仍存在且 Pane 相符；不存在就不呼叫 Adapter，直接回傳「目標已不存在」；存在才呼叫 Adapter 的 focus。結果為 `FocusOutcome`（成功，或帶 `FocusFailure` 的失敗，`FocusFailure.message` 是使用者可讀原因）。最近一次失敗公開在 `lastFailure` 供 Popover 頂部顯示，成功時清空。
- **Adapter**：把外部資料來源（目前是 Herdr）轉成本專案資料模型的元件，介面為 `HerdrAdapter` protocol；`FakeHerdrAdapter` 是記憶體內的實作。
- **Seam**：可以在不改動呼叫端的情況下替換實作的介面接縫。本專案的測試 seam 是 `HerdrAdapter`（所有 Session 資料都透過 Fake Adapter 餵入）與 `SettingsStore`（偏好儲存以記憶體內實作替換）。
