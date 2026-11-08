# 07 — IdleVillager 品牌識別與命名規格

## 正式名稱

- 產品名稱：**IdleVillager**（大小寫固定；不要寫 Idle Villager / IdleVillage）。
- 中文介紹：**AI 村民工作狀態列**。
- 英文副標：**Your AI Agents at a Glance**。
- 首版整合：Herdr；不能將 Herdr 誤用為本產品名稱。
- 命名靈感來自即時戰略遊戲的「閒置村民」提示概念；本工具為獨立專案，不使用《世紀帝國》的官方美術、標誌或遊戲資產。

## 品牌視覺方向

- 核心圖像：**小村民／簡單工具／狀態數量**，可愛但不花俏。
- Menu Bar 預設：IdleVillager 自有 Menu Bar Symbol（斗笠村民半身）+ 各狀態的 SF Symbol 與數量；零數量可隱藏。
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
- **待新增**：IdleVillager 自有 App Icon（由設計階段建立，不以第三方品牌標誌取代）。Menu Bar Symbol 已完成，見下一節。

## 自有標誌（Issue #40）

IdleVillager 有兩個自有標誌，都是同一個「戴斗笠的村民」造型，只差在細節多寡。兩者都是單色 template 圖：只用一種顏色加透明背景，由系統依選單列或視窗外觀自動換成深色或淺色，因此在明暗模式與高對比模式下都清楚。

| 檔案 | 造型 | 用途 | 尺寸 |
| --- | --- | --- | --- |
| `assets/brand/idlevillager-menubar-symbol.svg` | 斗笠村民半身 | 選單列數量模式最左邊 | 16 pt |
| `assets/brand/idlevillager-popover-mark.svg` | 斗笠瞇眼臉 | Popover 標題列 | 24 pt |

- **來源**：本專案自行繪製（2026-11，Issue #40），屬專案自有素材。沒有使用《世紀帝國》的官方美術，也沒有使用 Claude、Codex、Gemini 的標誌或任何第三方品牌元素。斗笠只是常見的農民意象，不取自任何既有作品。
- **為什麼選單列和 Popover 用不同版本**：選單列只有 16 pt，閉眼線條會細到約 1 px，在非 Retina 螢幕上會糊成一顆圓，所以選單列用剪影最清楚的「村民半身」。Popover 標題列有 24 pt，放得下閉眼細節，所以用比較有個性、能帶出「閒置村民」打盹感的「瞇眼臉」。
- **不會被誤認為狀態**：標誌的輪廓（斗笠＋人形）和所有狀態圖示（`hammer.fill`、`hand.raised.fill`、`checkmark`、`zzz`、`exclamationmark`、`questionmark`）都不同，也不是單純的圓點，因此不會被當成狀態標記或隱藏狀態的「•」。選單列上標誌和第一個狀態圖示之間留 4 pt 間距。
- **程式端實作**：App 不讀取這兩個 SVG，而是在 `Sources/IdleVillagerApp/IdleVillagerMark.swift` 以 SwiftUI `Shape` 畫出同樣的圖形（`VillagerSymbolShape`、`SleepyVillagerMarkShape`）。兩邊共用同一套 18 × 18 設計格線座標，改圖時 SVG 和 Swift 必須一起改。
- **不受影響的情境**：斷線模式與零 Agent 模式仍維持原本的文字呈現；少量角色模式仍顯示每個 Session 的小村民角色，因為那些角色代表的是 Session，不是產品識別。

## 名稱使用規則

- 文件標題、App 顯示名稱、Popover 標題及發行包名稱統一使用 `IdleVillager`。
- Herdr 僅描述目前支援的資料來源及導回目標；未來新增來源仍沿用 IdleVillager 名稱。
- GitHub repo、Bundle ID、商標／專案撞名等在發布前確認，目前不宣稱已註冊或可用。
