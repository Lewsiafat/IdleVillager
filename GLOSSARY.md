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

## 其他

- **isStale**：表示某個 Session 的資料已經不新鮮的旗標；自上次成功更新超過門檻，或 Adapter 回報斷線時為 true。
- **Focus**：使用者點擊一列後，把 Herdr 對應視窗帶到前景並聚焦到指定 Pane 的動作；結果是成功，或帶明確原因的失敗。
- **Adapter**：把外部資料來源（目前是 Herdr）轉成本專案資料模型的元件，介面為 `HerdrAdapter` protocol；`FakeHerdrAdapter` 是記憶體內的實作。
- **Seam**：可以在不改動呼叫端的情況下替換實作的介面接縫。本專案只有一個測試 seam，就是 `HerdrAdapter`，所有測試都透過 Fake Adapter 餵資料。
