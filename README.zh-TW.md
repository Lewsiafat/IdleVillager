[English](README.md) | 繁體中文

# IdleVillager

> macOS 選單列中的 AI Agent「小村民」狀態監控工具。  
> 版本與變更紀錄見 [`CHANGELOG.md`](CHANGELOG.md)。  
> 本 repo 不附帶第三方品牌標誌。

<!-- hero screenshot (#46): menu bar counts + expanded list -->

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

Herdr 會先顯示 plugin 的內容並請你確認，接著建置 App，大約需要一到兩分鐘。建置完成後 IdleVillager 會自動開啟，之後每次 Herdr server 啟動也會自動開啟。關掉之後想再開啟，可以執行：

```sh
herdr plugin action invoke launch --plugin idlevillager
```

更新與移除：

```sh
herdr plugin update idlevillager
herdr plugin uninstall idlevillager
```

更新會重新建置，完成後自動結束舊版、開啟新版；即使你更新前已經關掉 App，更新完也會再開啟。移除 plugin 不會關閉正在執行的 App，請從選單列 Popover 的「結束 IdleVillager」關閉（英文介面為 Quit IdleVillager）。Herdr 移除 plugin 時會保留安裝檔案，位置在 `~/.config/herdr/plugins/github-installations/`。

裝好後在選單列看不到圖示時，通常是空間不夠：有瀏海的 MacBook 會把放不下的選單列圖示藏起來，而且不會有提示。請按住 ⌘ 把其他不常用的圖示拖出選單列，騰出空間。發佈方式的研究與細節見 [`docs/08-distribution.md`](docs/08-distribution.md)。

<!-- demo GIF (#46): click a session to jump back to Herdr -->

## 首版範圍

- 選單列：各狀態數量與簡單視覺符號
- 清單：Workspace / Tab / Pane / Agent 階層
- 操作：點選 Session 後定位並切回 Herdr
- 角色：Claude、Codex、Gemini、Generic 的辨識與動畫資源規範
- 狀態：Working、Needs Approval、Done、Idle、Error、Unknown
- 介面語言：支援英文與繁體中文（不支援簡體中文）。App 啟動時跟隨 macOS 偏好語言清單，採用第一個支援的語言；兩者都不在清單中時使用英文。語言在啟動時決定，變更系統語言後需重新開啟 App。沒有 App 內的語言切換。

## 文件導覽

- [`docs/01-product-requirements.md`](docs/01-product-requirements.md)：產品需求、範圍與驗收條件
- [`docs/02-ui-ux-spec.md`](docs/02-ui-ux-spec.md)：選單列和展開清單視覺與操作
- [`docs/03-agent-states.md`](docs/03-agent-states.md)：狀態定義及計數規則
- [`docs/04-assets-animation.md`](docs/04-assets-animation.md)：圖片缺口、資源規格與動畫動作
- [`docs/05-herdr-integration.md`](docs/05-herdr-integration.md)：整合邊界、待驗證 API、切換流程
- [`docs/06-architecture-decisions.md`](docs/06-architecture-decisions.md)：技術方向、限制與決策
- [`docs/07-brand-identity.md`](docs/07-brand-identity.md)：IdleVillager 品牌、圖示、名稱與視覺語彙
- [`docs/08-distribution.md`](docs/08-distribution.md)：發佈方式研究（Herdr plugin、GitHub Releases、Homebrew Cask）
- [`docs/09-release-process.md`](docs/09-release-process.md)：版號規則、CHANGELOG 寫法與發版步驟
- [`CHANGELOG.md`](CHANGELOG.md)：各版本的變更紀錄
- [`planning/roadmap.md`](planning/roadmap.md)：P0/P1/P2 開發階段與完成條件
- [`planning/open-questions.md`](planning/open-questions.md)：尚未確認的環境與技術問題

## 目錄結構

```text
IdleVillager/
├── README.md                  # 英文版 README
├── README.zh-TW.md            # 繁體中文版 README
├── CHANGELOG.md
├── CLAUDE.md                  # 開發 Agent 的專案指示
├── GLOSSARY.md                # 專案詞彙表
├── Package.swift              # Swift Package 定義
├── herdr-plugin.toml          # Herdr plugin manifest，也是版號的唯一來源
├── Sources/
│   ├── IdleVillagerCore/      # 狀態正規化、Herdr adapter 等核心邏輯
│   └── IdleVillagerApp/       # SwiftUI 選單列 App
│       └── Resources/Brands/  # 第三方品牌標誌的放置位置（預設只有說明文件）
├── Tests/
│   └── IdleVillagerCoreTests/
├── assets/
│   └── brand/                 # IdleVillager 自有的選單列與 Popover 標誌（SVG）
├── distribution/              # make-app.sh、launch.sh、release-notes.sh
├── docs/
│   ├── 01-product-requirements.md … 09-release-process.md
│   ├── adr/                   # 架構決策紀錄
│   └── agents/                # 開發 Agent 使用的流程說明
├── planning/
│   ├── roadmap.md
│   └── open-questions.md
└── specs/                     # 各功能的規格與 walkthrough
```

## 給開發 Agent 的指示

開始前先閱讀 `CLAUDE.md`、`docs/` 與 `planning/` 文件。以 `swift test` 執行測試，以 `swift run IdleVillagerApp` 執行開發版。不得以 CPU 使用率低或停止輸出等單一訊號假定 Agent 已閒置；不得聲稱 API 已驗證，除非在使用者環境完成測試。

## 素材與商標

本 repo **沒有附帶第三方品牌素材**。`assets/brand/` 只放 IdleVillager 自有的標誌。Claude、Codex、Gemini 的官方標誌需依各自的來源、版本及使用條款另行取得，放置位置與規格見 [`Sources/IdleVillagerApp/Resources/Brands/README.md`](Sources/IdleVillagerApp/Resources/Brands/README.md)；沒有放入標誌時，角色會自動改用 Generic 小村民。
