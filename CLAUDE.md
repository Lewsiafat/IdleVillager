# IdleVillager

macOS 選單列工具：監控多個 AI Agent（Claude Code、Codex、Gemini）的工作狀態，並能一鍵切回對應的 Session。

## 專案主軸

靈感來自《世紀帝國 2》的「閒置村民」提示：玩家不用逐一巡視，就知道有多少村民沒事做，按一下就跳到那個村民身上。
本專案把這個概念套用到多 Agent 工作流，解決「同時跑多個 Agent 時，看不出誰在工作、誰在等我核准、誰閒置」的狀態觀測問題。
一句話定位：**看數量 → 找到 Workspace / Tab / Pane → 一鍵切回原 Session**。

## 目前狀態

- 版本 0.2，**只有規格文件，沒有任何程式碼、Xcode 專案或圖片素材**。`assets/` 與 `design/` 是空的預留目錄。
- 首個資料來源是 Herdr（終端多工工具），但 Herdr 只是整合目標，不是產品名稱。
- 技術方向：SwiftUI + MenuBarExtra，本機執行，無帳號與雲端。

## 文件導覽（先讀 README.md）

- `docs/01-product-requirements.md`：三個不可妥協需求、P0/P1/P2 範圍、驗收標準。
- `docs/02-ui-ux-spec.md`：選單列文字（`⚒ 3  ✋ 2  💤 1`）與 Popover 清單規格。
- `docs/03-agent-states.md`：六種正規化狀態（Working / Needs Approval / Done / Idle / Error / Unknown）與計數規則。
- `docs/04-assets-animation.md`、`docs/07-brand-identity.md`：角色、道具、動畫與命名規範。
- `docs/05-herdr-integration.md`：Herdr 整合待驗證清單，**不是已確認的 API 文件**。
- `docs/06-architecture-decisions.md`：模組邊界與核心決策。
- `planning/roadmap.md`、`planning/open-questions.md`：階段目標與尚未確認的問題。

## 硬性規則

- 產品名稱固定寫 `IdleVillager`，不寫 Idle Villager 或 IdleVillage。
- 不以 CPU 低、程序存活、終端久未輸出等單一訊號判定 Agent 閒置；訊號不足就顯示 Unknown。
- Done 不等於 Idle；Needs Approval 優先於 Idle。
- Herdr 斷線時顯示斷線，不顯示零個 Agent 或過期數字。
- 不得聲稱 Herdr API 已驗證，除非在使用者環境實際測試過。
- 只讀取 Session metadata，不讀取對話內容、Prompt、密碼或 API Key。
- 不使用《世紀帝國》官方美術或資產；第三方 Agent 品牌圖需自行依授權取得。
- 可及性：狀態必須同時有圖示與數字，不能只靠顏色。

## Agent skills

### Issue tracker

Issues live in GitHub Issues of `Lewsiafat/IdleVillager` (use the `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` at the repo root plus `docs/adr/`. See `docs/agents/domain.md`.
