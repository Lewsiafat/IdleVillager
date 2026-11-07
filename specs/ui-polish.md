# 外觀調整：選單列、Popover、角色動畫與設定視窗

- **分支:** `feat/ui-polish`
- **基底分支:** `main`
- **Worktree:** `/Users/lewis.chan/Documents/workspaceAI/IdleVillager-starter/.claude/worktrees/ui-polish`
- **日期:** 2026-11-07

## 描述
整體調整 IdleVillager 的外觀：選單列數量模式加上小村民圖示並把狀態圖示換成 SF Symbol（解決「幹活中」⚒ 太小不明顯的問題）、Popover 稍微放大並加入 Workspace 分組背景、列 hover 高亮、膠囊狀態標籤與標題列／footer 重排、角色構圖與動畫節奏微調、設定視窗加入選單列預覽並整理版面。

所有改動以 `Sources/IdleVillagerApp` 的畫面層為主，不改 Core 的狀態判定、排序與計數邏輯；唯一動到 Core 的是 `CharacterMotion.swift` 的動畫參數常數。
狀態仍必須同時有圖示與文字，顏色只是輔助；高對比模式一律改用主要前景色或實線框。

## 任務清單

### 選單列
- [ ] 數量模式改以 `ImageRenderer` 畫成 template 圖片：最左放 16 pt 小村民，狀態圖示改用 SF Symbol（working `hammer.fill`、needsApproval `hand.raised.fill`、idle `zzz`、done `checkmark`、error `exclamationmark`、unknown `questionmark`）配數字；斷線與零 Agent 模式維持現狀
- [ ] 數量模式的無障礙文字維持現有中文描述（`MenuBarLabel.accessibilityText`）
- [ ] 低干擾提醒的強調樣式從 1.5 pt 線框改為圓角底色填滿（primary 色、低透明度），數量模式與角色模式共用同一種樣式；寬度在強調前後不得跳動

### Popover
- [ ] `SessionPopoverView.width` 360 → 400 pt，`maxListHeight` 480 → 560 pt
- [ ] 每個 Workspace 用圓角 `quaternary` 底色區塊包起來，Tab 與 Session 列置於區塊內
- [ ] Session 列加 hover 高亮（淡 `selection` 底色）與 pointing hand 游標
- [ ] 右側狀態文字改為膠囊標籤：圖示加文字置於圓角膠囊，底色依狀態（綠／橘／黃／紅／灰）；高對比模式改為實線框加 primary 文字；「（過期）」字樣照常保留
- [ ] 標題列左側加 24 pt 小村民圖示
- [ ] footer 重排為兩列：第一列來源與連線資訊加更新時間，第二列「設定…」與「結束 IdleVillager」；`SettingsEntryButton` 併入 footer，整體高度縮短

### 角色與動畫
- [ ] 28 pt 角色本體比例 0.48 → 約 0.54，道具與特效相對縮小並往本體靠；16 pt 只畫本體的行為不變
- [ ] `CharacterMotion.swift` 參數：workingBob period 1.2 → 1.6 秒、rotationDegrees 4 → 3；idleZzz offset 0.2 → 0.15
- [ ] 更新 `CharacterMotionTests` 與 `CharacterPresentationTests` 中鎖定舊數值的測試

### 設定視窗
- [ ] 頂部新增「選單列預覽」區段：以示範資料依目前設定即時畫出數量模式或角色模式
- [ ] 版面整理：寬度 380 → 420，說明文字改用 `.caption`，分組順序為預覽、選單列、清單與提醒

### 驗證
- [ ] `swift build` 與 `swift test` 全數通過
- [ ] 以 `IDLEVILLAGER_DEMO=1` 啟動，實機確認明暗模式、高對比與 Reduce Motion 下的外觀
