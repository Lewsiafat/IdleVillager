# 05 — Herdr 整合計畫與待驗證清單

> 此文件列出整合目標與驗證步驟。待驗證清單已於 2026-11-05 在使用者環境以 Herdr 0.9.5 實測完成，結論記錄在 `docs/adr/0002-herdr-socket-api.md`；其他版本仍應重新核對。

## 需取得的能力

1. 列出 Workspace / Tab / Pane 階層與穩定識別碼。
2. 辨識每個 Pane 對應的 Agent 種類與 Agent Session。
3. 取得進行中、等待核准、完成、閒置及異常訊號（若有）。
4. 訂閱狀態變更或使用低成本輪詢。
5. 由 Workspace / Tab / Pane ID 定位 Session。
6. 將 Herdr 對應視窗真正帶到 macOS 前景。

## 待實機驗證（已於 2026-11-05 在使用者環境完成，詳見 `docs/adr/0002-herdr-socket-api.md`）

- [x] Herdr 是 TUI 或獨立桌面 App？版本是多少？——TUI 加常駐 `herdr server`；0.9.5，protocol 22。
- [x] 是否有本機 Socket / IPC？其位置、權限、訊息格式為何？——`~/.config/herdr/herdr.sock`，newline-delimited JSON，schema 可由 `herdr api schema --json` 匯出。
- [x] Session snapshot 能否顯示所有 Tab / Pane？——`session.snapshot` 回傳全部 Workspace / Tab / Pane / Agent。
- [x] 是否可直接取得 agentKind 與真實任務狀態？——`agents[].agent` 與 `agent_status`。
- [x] 是否能區分 Done、Idle、Blocked / Approval？——可以，`done` / `idle` / `blocked` 三者由伺服器區分。
- [x] 焦點 API 是否能定位單一 Pane？——`agent.focus` 與 `pane.focus` 可直接定位，並切換 Workspace 與 Tab。
- [x] 焦點成功後 macOS 是否把正確視窗移到前景？——不會，需由本專案把終端機 App（本機為 Ghostty）帶到前景。
- [x] 多工作區、多視窗、同名 Tab、同類 Agent 的情況是否可用？——ID 穩定唯一，實測 5 個 Claude Code Session 不混淆。
- [x] Herdr 重啟、關閉及版本更新時如何處理？——socket 路徑固定，重連即可；`ping` 回傳 protocol 可偵測不相容。注意 `herdr server stop` 會連同 pane 裡的 Agent 一起結束，重啟後所有 Agent 都是新的程序，`terminal_id` 全部換新；本專案以 `terminal_id` 當 Session ID，所以重連後清單會整批換成新的 Session，這是預期行為。

## 點擊一列的預期流程

1. 以穩定 Session / Pane ID 取得目標。
2. 驗證目標仍存在，不使用過期清單索引。
3. 呼叫受支援的 Herdr Focus / 導航能力。
4. 驗證目標 Tab / Pane 確實取得焦點。
5. 視需要啟用對應 macOS 視窗到前景。
6. 若無法完整完成，向使用者顯示明確失敗原因。

## 安全與隱私

- 僅讀取監控及定位所需的 Session metadata。
- 不讀取 Prompt、聊天內容、密碼或 API Key。
- 不將本機 Socket 或監控資訊向外網暴露。
- 記錄排錯資訊時只記非敏感事件種類與必要識別碼。

## 驗證情境

- 同 Workspace / Tab 下多個 Pane。
- 不同 Tab 各有同名 Agent。
- 多個同類 Claude Code Session 同時存在。
- Agent 從 Working → Approval → Working → Done。
- 關閉部分 Pane 後列表是否正確移除。
- Herdr 不在前景時點擊目標能否跳回。
