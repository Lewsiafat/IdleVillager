# IdleVillager — 專案初始資料包

> 版本：0.2（IdleVillager 命名版；文件與目錄骨架）  
> 目標：macOS 選單列中的 AI Agent「小村民」狀態監控工具  
> **本資料包不包含程式碼、Xcode 專案、可執行檔、圖片或品牌標誌。**

## 專案識別

- **產品名稱**：IdleVillager
- **英文副標**：Your AI Agents at a Glance
- **中文定位**：AI 村民工作狀態列
- **命名靈感**：《世紀帝國》的閒置村民提示；不隸屬或代表遊戲官方。
- **首個資料來源**：Herdr（僅整合目標，不是產品名稱）。

## 一句話定位

**看數量 → 找到 Workspace / Tab / Pane → 一鍵切回原 Session。**

選單列平時用極簡狀態數量呈現正在工作、等待處理及閒置的 Agent；展開後用品牌辨識的小角色及輕動畫呈現細節。工具以 Herdr 為主要整合目標。

## 安裝

IdleVillager 以 Herdr plugin 的形式發佈。安裝時會在你的電腦上由原始碼建置 App，所以不需要處理 macOS 對未簽章 App 的阻擋。

前置需求：

- macOS 14 以上。
- Herdr 0.9.5 以上，並且正在使用 Herdr TUI。
- Xcode Command Line Tools（提供 Swift 6 編譯器）。還沒安裝的話，執行 `xcode-select --install`。

安裝：

```sh
herdr plugin install Lewsiafat/IdleVillager
```

Herdr 會先顯示 plugin 的內容並請你確認，接著建置 App，第一次大約需要一到兩分鐘。之後每次 Herdr server 啟動，都會自動開啟 IdleVillager。想立刻開啟，可以執行：

```sh
herdr plugin action invoke launch --plugin idlevillager
```

更新與移除：

```sh
herdr plugin update idlevillager
herdr plugin uninstall idlevillager
```

移除 plugin 不會關閉正在執行的 App，請從選單列的「結束 IdleVillager」關閉。發佈方式的研究與細節見 `docs/08-distribution.md`。

## 首版範圍

- 選單列：各狀態數量與簡單視覺符號
- 清單：Workspace / Tab / Pane / Agent 階層
- 操作：點選 Session 後定位並切回 Herdr
- 角色：Claude、Codex、Gemini、Generic 的辨識與動畫資源規範
- 狀態：Working、Needs Approval、Done、Idle、Unknown / Error

## 文件導覽

- `docs/01-product-requirements.md`：產品需求、範圍與驗收條件
- `docs/02-ui-ux-spec.md`：選單列和展開清單視覺與操作
- `docs/03-agent-states.md`：狀態定義及計數規則
- `docs/04-assets-animation.md`：圖片缺口、資源規格與動畫動作
- `docs/05-herdr-integration.md`：整合邊界、待驗證 API、切換流程
- `docs/06-architecture-decisions.md`：技術方向、限制與決策
- `docs/07-brand-identity.md`：IdleVillager 品牌、圖示、名稱與視覺語彙
- `docs/08-distribution.md`：發佈方式研究（Herdr plugin、GitHub Releases、Homebrew Cask）
- `planning/roadmap.md`：P0/P1/P2 開發階段與完成條件
- `planning/open-questions.md`：尚未確認的環境與技術問題

## 目錄結構

```text
IdleVillager-starter/
├── README.md
├── docs/
│   ├── 01-product-requirements.md
│   ├── 02-ui-ux-spec.md
│   ├── 03-agent-states.md
│   ├── 04-assets-animation.md
│   ├── 05-herdr-integration.md
│   ├── 06-architecture-decisions.md
│   ├── 07-brand-identity.md
│   └── 08-distribution.md
├── assets/
│   ├── brands/             # 預留官方品牌向量圖
│   ├── props/              # 預留手腳、工具、枕頭等道具
│   └── effects/            # 預留 Zzz、驚嘆號、星光等特效
├── design/
│   └── references/         # 預留 UI 靈感與參考素材
└── planning/
    ├── roadmap.md
    └── open-questions.md
```

## 給開發 Agent 的起始指示

閱讀所有 `docs/` 與 `planning/` 文件，先驗證目標 Herdr 版本、可取得的 Session 狀態與 Focus/定位機制，再建置核心監控。不得以 CPU / 停止輸出等單一訊號假定 Agent 已閒置；不得聲稱 API 已驗證，除非在使用者環境完成測試。

## 素材與商標

官方標誌由後續實作者依來源、版本及使用條款取得。此資料包**沒有附帶第三方品牌素材**；`assets/` 為空資料夾，供實作時填入。
