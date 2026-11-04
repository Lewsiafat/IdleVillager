# 07 — IdleVillager 品牌識別與命名規格

## 正式名稱

- 產品名稱：**IdleVillager**（大小寫固定；不要寫 Idle Villager / IdleVillage）。
- 中文介紹：**AI 村民工作狀態列**。
- 英文副標：**Your AI Agents at a Glance**。
- 首版整合：Herdr；不能將 Herdr 誤用為本產品名稱。
- 命名靈感來自即時戰略遊戲的「閒置村民」提示概念；本工具為獨立專案，不使用《世紀帝國》的官方美術、標誌或遊戲資產。

## 品牌視覺方向

- 核心圖像：**小村民／簡單工具／狀態數量**，可愛但不花俏。
- Menu Bar 預設：小村民圖示 + `⚒ 3  ✋ 2  💤 1`；零數量可隱藏。
- Popover 標題：`IdleVillager`，下方以 Workspace → Tab → Pane → Agent 展示。
- Agent 品牌標誌（Claude／Codex／Gemini）僅作為可辨識的角色本體，遵循各品牌使用規範。
- 自有產品標誌與第三方 Agent 圖示分開管理。

## 動態狀態語彙

| 狀態 | 角色動作 | 說明 |
| --- | --- | --- |
| Working | 揮榔頭、敲鍵盤 | 輕微循環 |
| Needs Approval | 舉手、提示符號 | 優先醒目但不閃爍 |
| Done | 舉旗、跳一下 | 狀態轉換時播放一次 |
| Idle | 躺平、Zzz | 靜態為主、低頻動作 |
| Unknown / Error | 疑惑／警示 | 不將未知誤判為閒置 |

## 尚缺素材（本 ZIP 不包含任何圖檔）

- `assets/brands/`：Claude、Codex、Gemini 的合法來源標誌、通用 Agent 圖形。
- `assets/props/`：鎚子、鍵盤、舉手、枕頭、床、旗子。
- `assets/effects/`：Zzz、驚嘆號、星光。
- `design/references/`：風格參考圖（後續取得權限後加入）。
- **待新增**：IdleVillager 自有 App Icon／Menu Bar Symbol（由設計階段建立，不以第三方品牌標誌取代）。

## 名稱使用規則

- 文件標題、App 顯示名稱、Popover 標題及發行包名稱統一使用 `IdleVillager`。
- Herdr 僅描述目前支援的資料來源及導回目標；未來新增來源仍沿用 IdleVillager 名稱。
- GitHub repo、Bundle ID、商標／專案撞名等在發布前確認，目前不宣稱已註冊或可用。
