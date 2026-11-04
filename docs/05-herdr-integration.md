# 05 — Herdr 整合計畫與待驗證清單

> 此文件列出整合目標與驗證步驟，**不是已確認的 Herdr API 文件**。實作前應以使用者安裝的版本與官方文件核對名稱、傳輸格式和可用功能。

## 需取得的能力

1. 列出 Workspace / Tab / Pane 階層與穩定識別碼。
2. 辨識每個 Pane 對應的 Agent 種類與 Agent Session。
3. 取得進行中、等待核准、完成、閒置及異常訊號（若有）。
4. 訂閱狀態變更或使用低成本輪詢。
5. 由 Workspace / Tab / Pane ID 定位 Session。
6. 將 Herdr 對應視窗真正帶到 macOS 前景。

## 待實機驗證（不可預設成功）

- [ ] Herdr 是 TUI 或獨立桌面 App？版本是多少？
- [ ] 是否有本機 Socket / IPC？其位置、權限、訊息格式為何？
- [ ] Session snapshot 能否顯示所有 Tab / Pane？
- [ ] 是否可直接取得 agentKind 與真實任務狀態？
- [ ] 是否能區分 Done、Idle、Blocked / Approval？
- [ ] 焦點 API 是否能定位單一 Pane？若不能，是否有其他受支援的方法？
- [ ] 焦點成功後 macOS 是否把正確視窗移到前景？
- [ ] 多工作區、多視窗、同名 Tab、同類 Agent 的情況是否可用？
- [ ] Herdr 重啟、關閉及版本更新時如何處理？

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
