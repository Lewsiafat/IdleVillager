# 04 — 圖片資源與動畫規格

## 素材策略

建議：**品牌 SVG / 向量資產 + 可重用的道具/效果圖 + SwiftUI 動畫**。專案初始包不附第三方 Logo 或圖片，也不包含程式碼。

實作：角色以 SwiftUI 繪製。持續播放的循環動作（幹活、舉手、躺平）交給 Core Animation 播放，一個週期的關鍵影格由 `IdleVillagerCore` 的 `CharacterLoop.keyframes` 描述；狀態轉換時只播一次的過渡仍用 SwiftUI。改用 Core Animation 的原因是 SwiftUI 的 `PhaseAnimator` 每一幀都要在主執行緒重做整個清單視窗的版面配置，連靜止時段也一樣，清單開著時 CPU 約 10%（#56）。

## 必須取得的外部品牌素材

| 檔名（預定） | 內容 | 取得要求 | 狀態 |
|---|---|---|---|
| assets/brands/claude.svg | Claude 官方品牌圖案 | 官方素材來源及使用規範 | 缺少 |
| assets/brands/codex.svg | OpenAI / Codex 對應官方品牌識別 | 確認當前可用的品牌素材及規範 | 缺少 |
| assets/brands/gemini.svg | Gemini 官方品牌識別 | 官方素材來源及使用規範 | 缺少 |

## 自製通用素材（尚未繪製）

| 檔名（預定） | 內容 | 動作 |
|---|---|---|
| assets/brands/generic-agent.svg | 未辨識 Agent 的中性角色 | 所有狀態 |
| assets/props/hammer.svg | 榔頭 | Working |
| assets/props/keyboard.svg | 鍵盤 | Working |
| assets/props/hand.svg | 舉手部件 | Needs Approval |
| assets/props/pillow.svg | 枕頭 | Idle |
| assets/props/bed.svg | 床／躺平道具 | Idle |
| assets/props/flag.svg | 完工旗 | Done |
| assets/effects/zzz.svg | 睡覺文字／特效 | Idle |
| assets/effects/exclamation.svg | 待處理驚嘆號 | Needs Approval |
| assets/effects/sparkle.svg | 完成亮光 | Done |

優先研究 SF Symbols / SwiftUI Shapes 來代替簡單道具，避免不必要素材檔案。

## 動畫說明

| 狀態 | 動態設計 | 頻率原則 |
|---|---|---|
| Working | 角色微幅上下跳動、手臂敲鍵盤或揮工具 | 平穩、低干擾循環 |
| Needs Approval | 舉手、提示小幅晃動 | 稀疏節奏、不可閃爍 |
| Done | 跳一下／升旗 | 只在狀態切換時播放一次 |
| Idle | 躺平，Zzz 偶爾浮出 | 低頻率 |
| Error | 靜態警示或短促提示 | 避免永久閃動 |
| Unknown | 靜態疑問符號 | 不需動畫 |

## 圖形設計準則

- Logo 本體不隨意改色或扭曲，以獨立外層道具及動作表現角色個性。
- 品牌辨識優先：16–18 pt 中仍應可辨識；小尺寸可以只保留主標誌。
- 使用向量版母檔，實作時採取相容於 macOS 資產系統的輸出方式。
- 動作可拆分為本體、手、腳、道具、表情、特效等圖層。
- 每個狀態都有不依賴動畫的靜態版本。
- 支援深色、淺色與 macOS Reduce Motion。

## 驗收

- [ ] 素材擁有可追溯來源與商標使用許可。
- [ ] Claude / Codex / Gemini 小尺寸可辨識。
- [ ] 未知 Agent 有中性備援角色。
- [ ] 角色動畫可由狀態驅動，不靠預錄長 GIF。
- [ ] 同時顯示多個角色不造成明顯高 CPU 使用率。


## IdleVillager 角色風格

- 以「AI 村民」為核心意象，工作工具／枕頭／舉手是狀態語言。
- 品牌圖像只辨識 Agent 類別，不應取代 IdleVillager 自身 Logo。
- 參照 `07-brand-identity.md` 的視覺與命名規範。
