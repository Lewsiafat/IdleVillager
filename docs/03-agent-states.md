# 03 — Agent 狀態模型與數量規則

## 正規化狀態

| 狀態 | 語意 | 主要呈現 | 動作 |
|---|---|---|---|
| Working | Agent 正在執行任務或有可靠的進行中訊號 | `⚒` 綠 | 幹活 |
| Needs Approval | 等待核准、回答、權限或其他需要人的輸入 | `✋` 紅／橘 | 舉手 |
| Done | 任務已完成，可能尚未被查看 | `✓` 黃／綠 | 交工跳躍一次 |
| Idle | Session 存在，但無活躍任務 | `💤` 灰 | 躺平 |
| Error | 已確認任務失敗或異常 | `!` 紅 | 警示 |
| Unknown | 訊號不足或無法對應 | `?` 灰 | 疑惑 |

## 計數

- 統計單位為 **可辨識的 Agent Session 實例**，不等於 Terminal 視窗數，也不等於 Tab 數。
- 每個可監控 Session 只被計入一種正規化狀態。
- 預設 Menu Bar 只呈現 Working / Needs Approval / Idle 的數量；Done / Error / Unknown 必須有可辨識的提示或在展開清單中看得到，避免無聲遺失。
- 不要把 Done 當作 Idle；Done 表示任務完成，Idle 表示沒有活躍任務。兩者依 Herdr 可提供的實際事件判定。
- 若多個互斥訊號衝突，顯示 Unknown 或明確衝突提示，並記錄觀察所需的非敏感事件 metadata。
- 例外：Needs Approval 優先於 Idle。同一個 Agent Session 同時帶有 Needs Approval 與 Idle 訊號時，結果為 Needs Approval，不算衝突，也不附衝突描述。這是上一條規則的刻意例外，理由是等核准的 Agent 本來就沒在動，兩個訊號並不真正互斥；若判為 Unknown，等核准的 Agent 會被顯示成訊號不足，造成漏看。此例外只限 Needs Approval 與 Idle 這一組；其他組合（例如 Done 與 Idle、Working 與 Idle）仍是衝突，結果為 Unknown。若除了 Idle 之外還有其他互斥訊號（例如 Needs Approval、Idle 與 Error 同時出現），仍判為 Unknown。
- 在 Herdr 斷線時停止展示看似即時的舊數字，顯示斷線／資料過期狀態。

## 資料欄位（概念模型，非 API 保證）

- workspaceID / workspaceName
- tabID / tabName
- paneID / paneLabel
- agentSessionID / agentKind / displayName
- rawState / normalizedState
- updatedAt / stateSource / isStale

所有 ID 都應使用實際來源提供的穩定識別碼，不可用列表序號或名稱替代。

## 動畫狀態轉換

- Working → Done：播放一次慶祝，再維持完成姿勢。
- Working → Needs Approval：切換舉手、顯示提示。
- 任意 → Idle：緩慢轉為躺平，不突然閃爍。
- Unknown 與 Error：不播放代表「確定成功」的動畫。

## 偵測政策

以 Herdr 明確事件 / 狀態 API 為首選。程序仍在執行、CPU 使用率低、終端機長時間未輸出都不能單獨證明 Agent 閒置。
