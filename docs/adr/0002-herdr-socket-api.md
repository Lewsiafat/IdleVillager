# ADR 0002：以 Herdr 的本機 Socket API 作為資料來源

- 狀態：已採用
- 日期：2026-11-05
- 驗證環境：macOS 14.8、Herdr 0.9.5（stable channel，protocol 22）、終端機 Ghostty（bundle id `com.mitchellh.ghostty`）

## 背景

`docs/05-herdr-integration.md` 列了一份待驗證清單，規定在使用者環境實際測試前不得聲稱 Herdr API 已確認。本決策記錄 2026-11-05 在使用者機器上實測的結果，作為 #8 真實 Adapter 的依據。所有結論都來自實際執行 `herdr` CLI 與直接連 socket 的結果，不是文件推測。

## 驗證結果

### 客戶端型態與版本

Herdr 是 TUI，跑在使用者的終端機 App（本機為 Ghostty）裡。`herdr server` 是獨立的常駐程序（headless），TUI 客戶端與 CLI 都透過同一個 socket 和它溝通。`herdr status` 可查客戶端與伺服器版本、protocol 與 socket 路徑。

### IPC 位置與格式

- Unix domain socket：`~/.config/herdr/herdr.sock`（預設 session）。具名 session 各有自己的 socket，`herdr session list` 會列出路徑。
- 訊息格式：一行一個 JSON（newline-delimited JSON）。請求為 `{"id": "<string>", "method": "<name>", "params": {...}}`，`id` 必填，`params` 必填（沒有參數時給 `{}`）。
- 成功回應 `{"id", "result": {"type": "...", ...}}`；錯誤回應 `{"id", "error": {"code", "message"}}`。已觀察到的錯誤碼：`invalid_request`、`agent_not_found`。
- 完整 JSON Schema 可由 `herdr api schema --json` 匯出，分成 `request`、`success_response`、`error_response`、`event`、`subscription_event` 五份。
- `ping` 回傳版本、protocol 與 capabilities，可作為連線健康檢查。
- 沒有送任何請求的連線，伺服器約 5 秒後主動關閉。

### 快照

`session.snapshot`（CLI：`herdr api snapshot`）一次回傳完整階層：`workspaces`（`workspace_id`、`label`、`number`、`agent_status`）、`tabs`（`tab_id`、`workspace_id`、`label`、`number`）、`panes`、`agents`、`layouts` 與目前聚焦的 workspace / tab / pane。實測 4 個 Workspace、12 個 Tab、15 個 Pane 全部列出。

`agents` 陣列只含有辨識到 Agent 的 Pane，每筆有：`pane_id`、`tab_id`、`workspace_id`、`terminal_id`（Pane 存活期間穩定）、`agent`（種類字串，例如 `claude`）、`agent_status`、`agent_session`（可選，含 Agent 自己的 session id）、`terminal_title_stripped`、`cwd`、`revision`、`state_change_seq`、`completion_seq`。**沒有任何時間戳記欄位**。

沒有 Agent 的 Pane 在 `panes` 陣列中 `agent` 欄位缺席、`agent_status` 為 `unknown`，不應列為 Agent Session。

### 狀態語意

`agent_status` 列舉只有五種：`idle`、`working`、`blocked`、`done`、`unknown`。依 Herdr 自己的說明（`herdr --skill`）：

- `blocked`：Herdr 辨識到核准或提問 UI。對應本專案的 Needs Approval。
- `done`：Agent 完成一輪工作，且尚未被「看過」；伺服器以聚焦指令標記已看過，讀取不算。對應 Done。
- `idle`：準備接受輸入。對應 Idle。
- `working`：對應 Working。
- `unknown`：有 Agent 但無法可靠分類，不代表完成。對應 Unknown。

Done 與 Idle 由伺服器區分，不需要在本專案合併成 Unknown。Herdr 沒有錯誤狀態，Error 不會由此來源產生。狀態由 Herdr 以畫面規則判定（`herdr agent explain` 可看規則與證據），屬於明確事件，`stateSource` 取 `explicitEvent`。

支援的 Agent 種類（`herdr agent start --kind`）包含 `claude`、`codex`、`gemini`、`cursor`、`copilot`、`opencode` 等 24 種。

### 事件訂閱

- `events.subscribe` 的 `params.subscriptions` 是陣列，每項 `{"type": "..."}`。生命週期類（`pane.created`、`pane.closed`、`pane.updated`、`pane.focused`、`pane.exited`、`pane.agent_detected`、`tab.*`、`workspace.*`、`layout.updated`）不需要額外參數；`pane.agent_status_changed` 必須逐個 Pane 指定 `pane_id`。
- 成功後回 `{"result": {"type": "subscription_started"}}`，之後事件以 `{"event": "<kind>", "data": {...}}` 推送。實測收到 `pane_focused`、`tab_focused`、`workspace_focused`、`pane.agent_status_changed`（`data` 含 `pane_id`、`workspace_id`、`agent`、`agent_status`）。
- **訂閱連線是專用的**：訂閱成功後在同一條連線再送任何請求，伺服器會立刻關閉連線。也無法在同一條連線追加訂閱。
- 訂閱中的連線不會被閒置關閉（實測 2 分鐘內持續開啟）。

### 聚焦與前景

- `agent.focus`（`params.target` 為 pane id 或 agent 名稱）與 `pane.focus`（`params.pane_id`）都能定位單一 Pane，並同時切換 Workspace 與 Tab。回應帶回該 Agent 的最新資訊，`focused: true` 可用來驗證。目標不存在回 `agent_not_found`。
- 聚焦只作用在 Herdr TUI 內部，不會把終端機 App 帶到 macOS 前景。前景切換要由本專案自己做：找出執行 Herdr 客戶端的程序（`herdr` 程序中非 `herdr server` 者），沿父程序往上找到有 bundle 的 App（本機為 Ghostty），用 `NSRunningApplication.activate` 帶到前景。

### 多工作區、同名與同類 Agent

ID 為伺服器範圍內唯一且穩定（`w1`、`w1:t1`、`w1:p1`），關閉後不重用；Pane 移到別的 Workspace 會拿到新的 pane id 並發 `pane.moved`。實測同時有 5 個 Claude Code Session，彼此以 pane id 與 terminal id 區分，不混淆。Tab 與 Workspace 的 `label` 可重複，只能當顯示用。

### 重啟與版本

Socket 路徑固定。伺服器停止時 socket 檔案消失或連線被拒；重啟後路徑不變，重新連線即可。`ping` 回傳的 `protocol` 可用來偵測不相容版本（目前 22）。

## 決策

1. 真實 Adapter 以 Unix domain socket 直接使用 newline-delimited JSON 協定，不透過 `herdr` CLI 子程序。
2. 每次請求（`ping`、`session.snapshot`、`agent.focus`）使用一條短連線，送完即關。事件訂閱使用另一條專用長連線，訂閱全部生命週期事件加上每個已知 Agent Pane 的 `pane.agent_status_changed`。
3. 收到任何生命週期事件（Pane 或 Tab 或 Workspace 的新增、關閉、更新、移動、偵測到 Agent）時，重新取快照並與前一份比對，合成 `sessionAdded` 與 `sessionRemoved`；若已知 Agent Pane 集合改變，關閉舊訂閱連線並以新集合重建。`pane.agent_status_changed` 直接轉成 `sessionStateChanged`。
4. 來源沒有時間戳記，`updatedAt` 一律取 Adapter 收到資料的時間。Adapter 另外每 30 秒重新取一次快照作為對帳與保活，也讓 Store 的過期判定（#23 決定維持以最近一次成功快照為基準）在事件訂閱模式下成立。訂閱連線中斷時退回只靠這個輪詢，並以 1、2、4、8、16、30 秒的退避重試訂閱。
5. `rawState` 直接使用 Herdr 的五種 `agent_status` 字串，`StateNormalizer.rawStateTable` 以此為準：`blocked` 對應 Needs Approval（本決策推翻 #20 先前因缺乏驗證而移除的對應），`done` 對應 Done，`idle`、`working`、`unknown` 同名對應。
6. 識別碼對應：`AgentSessionID` 取 `terminal_id`；`WorkspaceID`、`TabID`、`PaneID` 取 Herdr 的 id。顯示名稱取 `terminal_title_stripped`，沒有時取 `agent` 種類；Workspace 與 Tab 名稱取 `label`。`agentKind` 取 `agent`。`waitingReason` 目前給 nil，因為來源沒有可靠的短說明欄位。
7. 聚焦流程：先以 `agent.get` 確認目標存在，再 `agent.focus`，檢查回應 `focused` 為 true，最後把 Herdr 客戶端所在的終端機 App 帶到前景；任何一步失敗回傳對應的 `FocusFailureReason`。
8. 只請求上述欄位；不呼叫 `agent.read`、`pane.read`、`agent.prompt` 等會接觸終端內容或送入文字的方法。日誌只記事件種類、連線狀態與 ID。

## 後果

- `HerdrAdapter` protocol 不需要改動即可實作。
- 真實 Adapter 不進自動化測試，但 JSON 解碼、快照比對與訂閱集合計算以固定的 JSON 樣本做單元測試。
- Herdr 升版若改變 protocol，`ping` 會先察覺；若狀態列舉新增值，會落到 Unknown 而不是誤判。
- 前景切換依賴程序樹推斷終端機 App，若 Herdr 以其他方式啟動（例如 `--remote`）可能找不到，此時回報 `windowNotBroughtToFront`。
