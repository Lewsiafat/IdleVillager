# 06 — 架構與決策紀錄

## 初始方向（待實作驗證）

- macOS 原生選單列工具，優先考慮 SwiftUI + MenuBarExtra。
- Herdr 為第一階段唯一監控來源。
- 單一資料正規化層，把來源狀態轉成 UI 狀態。
- 動畫與資料讀取分離；畫面只依據正規化狀態顯示。
- 使用向量圖案及原生動畫，不採持續播放的 GIF。
- 本機運行，無需帳號或雲端服務。

## 建議模組邊界（概念，不是原始碼目錄）

1. `Herdr Adapter` — 負責取得 Session / Pane metadata、狀態及焦點操作。
2. `State Normalizer` — 定義 UI 狀態、優先度與計數。
3. `Session Store` — 使用穩定 ID 管理即時 Session 清單。
4. `Menu Bar Summary` — 顯示數字、圖示及必要警示。
5. `Session Popover` — 按 Workspace / Tab / Pane 排列並允許定位。
6. `Character Presentation` — 將 Agent 品牌與狀態映射到圖層／動畫。

## 核心決策

- 低干擾高於動畫華麗程度。
- 不以猜測狀態偽裝精確監控。
- 一鍵定位回原 Pane 是必要功能，不是可選加分項。
- 可及性：顏色之外必須有圖示、文字或數字。
- 不附第三方品牌圖檔；後續依權利與來源補齊。

## 已決策事項

- 最低 macOS 版本：macOS 14，見 `docs/adr/0001-swift-package-and-minimum-macos.md`。
- Herdr 目標版次與客戶端型態、事件訂閱與輪詢備援方案：真實 Adapter（`HerdrSocketAdapter`）直接使用 Herdr 的本機 Unix domain socket，見 `docs/adr/0002-herdr-socket-api.md`。

## 待決策事項

- Menu Bar 是否持續顯示 Done / Error / Unknown 的小計數。
- 實作時採 SVG 轉 PDF / 向量 Asset，或其他原生可行管線。


## 命名決策（2026-11-03）

- 產品名稱確定為 **IdleVillager**。
- Herdr 是第一個整合 Adapter，不納入產品主名稱，以利日後增加其他來源。
- 專案資料夾採 `IdleVillager-starter/`，品牌資源不與 Agent 品牌資源混用。
