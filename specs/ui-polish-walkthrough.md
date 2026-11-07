# 外觀調整：選單列、Popover、角色動畫與設定視窗 — Walkthrough

- **分支:** `feat/ui-polish`
- **基底分支:** `main`
- **日期:** 2026-11-07

## 變更摘要
整體調整 IdleVillager 的外觀：選單列數量模式改成含小村民圖示的 template 圖片，狀態圖示改用 SF Symbol，解決「幹活中」⚒ 太小不明顯的問題；Popover 放大並加入 Workspace 分組背景、列 hover 高亮、膠囊狀態標籤與兩列 footer；角色構圖與動畫節奏微調；設定視窗加入選單列即時預覽並整理版面。
工作拆成 GitHub issues #35 到 #38 四張 tickets（父 issue #34），各自在獨立 worktree 以 TDD 實作後合併進整合分支，再經兩軸 code review（文件標準與規格）修正。`swift test` 共 230 個測試通過。

## 修改的檔案

### 選單列
- `Sources/IdleVillagerApp/IdleVillagerMenuBarApp.swift`：新增 `MenuBarCountsLabel`，數量模式改以 `ImageRenderer` 畫成 template 圖片，最左放 16 pt 小村民，後面是各狀態的 SF Symbol 與數量。斷線與零 Agent 模式和無障礙文字不變。
- `Sources/IdleVillagerApp/MenuBarImageRendering.swift`（新增）：數量模式與角色模式共用的產圖 helper。
- `Sources/IdleVillagerApp/MenuBarCharactersLabel.swift`：改用共用產圖 helper，強調樣式改為圓角底色。
- `Sources/IdleVillagerApp/MenuBarAlertModifier.swift`：新增 `menuBarEmphasisBackground(_:)`，兩種模式共用的圓角底色強調，內距固定所以寬度不跳動；更新 doc 註解。

### Popover
- `Sources/IdleVillagerApp/SessionPopoverView.swift`：寬度 400 pt、清單最大高度 560 pt；Workspace 以 `quaternary` 圓角區塊包起；Session 列 hover 高亮與 pointing hand 游標（以 `@State` 守衛 push/pop）；新增 `StatusCapsule`，高對比模式改實線框；標題列加 24 pt 靜態小村民；footer 重排為兩列並併入「設定…」。
- `Sources/IdleVillagerApp/SettingsView.swift`：`SettingsEntryButton` 去掉自己的 padding 與靠右 frame，改由 footer 排版。

### 角色與動畫
- `Sources/IdleVillagerApp/CharacterView.swift`：28 pt 角色本體比例 0.48 改 0.54，道具、特效、手腳相對縮小並往本體靠；16 pt 只畫本體的行為不變。
- `Sources/IdleVillagerCore/CharacterMotion.swift`：workingBob 的 period 與 motionDuration 1.2 改 1.6 秒、rotationDegrees 4 改 3；idleZzz offset 0.2 改 0.15。
- `Tests/IdleVillagerCoreTests/CharacterMotionTests.swift`：更新鎖定舊數值的斷言。

### 設定視窗
- `Sources/IdleVillagerApp/SettingsView.swift`：頂部新增 `MenuBarPreviewSection`，重用 `MenuBarLabel` 畫出目前模式的選單列；寬度 420 pt；分組順序為預覽、選單列、清單與提醒；「顯示完成小計數」文案去掉 ✓。
- `Sources/IdleVillagerApp/BehaviorSettingsSection.swift`：低干擾提醒的說明改用 `.caption`，文字改成「以圓角底色強調待核准項目」。
- `Sources/IdleVillagerCore/MenuBarPreview.swift`（新增）：`StoreSnapshot.menuBarPreview(for:)`，數量模式用完整示範資料，角色模式只取前三個 Session 以低於門檻。
- `Tests/IdleVillagerCoreTests/MenuBarPreviewTests.swift`（新增）。

### Core 對照表
- `Sources/IdleVillagerCore/StatePresentation.swift`：`StatePresentation` 新增 `symbolName` 與 `tint` 欄位，由同一個 switch 定義；`NormalizedState.symbolName` 與 `.tint` 為捷徑。
- `Sources/IdleVillagerCore/StateTint.swift`（新增）：`StateTint` enum（green、orange、yellow、red、gray）。
- `Sources/IdleVillagerCore/SessionStore.swift`：抽出 `StoreSnapshot.normalizedEntries(from:isStale:)`，Session Store 與選單列預覽共用正規化與計數。
- `Tests/IdleVillagerCoreTests/StatePresentationTests.swift`、`Tests/IdleVillagerCoreTests/StateTintTests.swift`：對照表測試。

### 文件
- `GLOSSARY.md`：更新「狀態呈現對照表」、「選單列模式」、「低干擾提醒」、「循環動作」，新增「狀態色調」、「數量模式小村民」、「選單列預覽」詞條。
- `specs/ui-polish.md`：規格與任務清單。

## 技術細節
- **Core 範圍**：規格原本寫 Core 只改動畫參數常數，實作時另外新增了三個純對照表（SF Symbol 名稱、色調、選單列預覽快照）。依「Core 純邏輯、App 只畫面」的架構決策與 `GLOSSARY.md`「呈現事實只定義在 `NormalizedState.presentation` 一處」的規則，這些放在 Core 比放在 App 層合適，規格文字已同步修改。
- **單一定義點**：code review 發現 `symbolName` 與 `tint` 起初各寫一個 switch，違反單一定義點規則，已併入 `StatePresentation`。
- **選單列強調**：數量模式只強調「等核准」那一格，與角色模式只強調待核准角色一致；底色只是額外提示，狀態仍由圖示表達。
- **數量模式小村民**：固定用站姿、只畫本體、不播動畫，只是識別圖示，不代表任何 Session 的狀態。實機看起來是一個實心圓點，辨識度不高，可作為後續改善項目。
- **選單列預覽**：示範資料有 7 個 Session，超過少量角色模式門檻會退回數量模式，所以角色模式預覽只取前三個。
- **hover 游標**：`NSCursor` 的 push 與 pop 以 `hasPushedCursor` 狀態守衛，`onDisappear` 時若仍 push 則 pop，避免事件漏發造成游標卡住。
- **實機驗證**：以真實 Herdr 資料在選單列確認數量模式外觀正常（透過 `open` 啟動時示範模式的環境變數沒有帶入）。Popover、設定預覽、深色模式、高對比與 Reduce Motion 的實機確認尚未回報，規格清單中保持未勾。
- **分支與 PR**：整合分支已推到遠端並開了 PR #39（ready for review，標記 Closes #34 到 #38）。本地 merge 回 `main` 後推送 `main`，GitHub 會把 PR 視為已合併並關閉 issues。
