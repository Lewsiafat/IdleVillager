# IdleVillager 詞彙表

本專案程式碼、測試與文件共用的核心詞彙。命名型別與測試時請使用這裡的詞。

## 來源階層

- **Workspace**：Herdr 中最上層的工作區，底下包含一個或多個 Tab。以來源提供的穩定 `WorkspaceID` 識別。
- **Tab**：Workspace 底下的分頁，底下包含一個或多個 Pane。以 `TabID` 識別，同名 Tab 仍以 ID 區分。
- **Pane**：Tab 內的一個分割窗格，是 Focus 的最終目標。以 `PaneID` 識別，`paneLabel` 只用於顯示。
- **Agent Session**：在某個 Pane 裡執行的一個 AI Agent 實例（例如一個 Claude Code Session），也是所有計數的單位。以 `AgentSessionID` 識別，它是 Session Store 的主鍵。

## 正規化狀態

每個 Agent Session 在任一時刻恰好屬於下列六種之一。

- **Working**：Agent 正在執行任務，或有可靠的進行中訊號。
- **Needs Approval**：Agent 在等人核准、回答或給權限，優先於 Idle。
- **Done**：任務已完成，可能還沒被查看；Done 不等於 Idle。
- **Idle**：Session 存在但沒有活躍任務，只能由明確事件推導，不能由 CPU 低或久未輸出推導。
- **Error**：已確認任務失敗或異常。
- **Unknown**：訊號不足、無法對應或訊號互相衝突時的狀態，必須明確顯示而不是被隱藏。

- **State Normalizer**：把 Adapter 給的 `rawState` 與 `stateSource` 轉成上述六種狀態之一的純函式（`StateNormalizer`）。只有明確事件能得到非 Unknown 的狀態；`rawState` 的對應表只定義在 `StateNormalizer.rawStateTable` 一處。
- **衝突描述（Conflict Note）**：一個 Session 同時帶有多個互斥訊號（`rawState` 以 `|` 分隔，例如 `working|idle`）時，該 Session 為 Unknown，並附上只含正規化狀態名稱的說明（例如「訊號衝突：Working、Idle」），不含任何來源原始文字。Needs Approval 與 Idle 同時出現不算衝突，結果為 Needs Approval。

## 選單列摘要

- **Menu Bar Summary**：由 Store 的計數與連線狀態推導出的純值摘要模型（`MenuBarSummary`），再由 `MenuBarSummaryFormatter` 轉成選單列文字，例如 `⚒ 3  ✋ 2  💤 1`。文字不含任何 Session 名稱。
- **摘要模式（Summary Mode）**：`normal`（顯示數量）、`disconnected`（斷線或重連中，只顯示斷線表示，不含任何數字）、`zeroAgents`（已連線但沒有 Agent Session，顯示「0 個 Agent」）。斷線模式的文字版為 `⚠ 斷線`；App 的選單列改用 `MenuBarSummaryFormatter.symbolName(for:)` 提供的 SF Symbol（`exclamationmark.triangle`）呈現斷線圖示，其他模式該值為 nil、顯示文字。
- **隱藏狀態提示（Hidden States）**：Done、Error、Unknown 不在選單列預設數量中；任一大於 0 時摘要模型的 `hasHiddenStates` 為 true，選單列尾端加上小標記 `•`。開啟 Done 小計數後，Done 不再算作隱藏狀態，Error 與 Unknown 仍然算。
- **選單列模式（Menu Bar Mode）**：使用者在設定中選擇的選單列呈現方式（`MenuBarMode`），分為數量模式（`counts`，預設，顯示摘要文字）與少量角色模式（`fewCharacters`）。
- **少量角色模式（Few Characters Mode）**：Session 很少時，選單列改為每個 Session 顯示一個靜態小村民角色（16 pt，只畫本體，不播放動畫），後面接狀態圖示（⚒ ✋ ✓ 💤 ! ?），讓狀態不只靠角色或顏色辨識。角色依清單優先度排列，不含任何 Session 名稱。是否真的顯示角色由純值模型 `MenuBarCharacterMode` 決定，輸出 `MenuBarDisplay`：`.counts` 或 `.characters([MenuBarCharacterItem])`。
- **少量角色門檻（Few Characters Threshold）**：少量角色模式最多顯示角色的 Session 數量（`fewCharactersThreshold`，預設 4，可注入）。Session 數量在 1 到門檻（含）之間且已連線時才顯示角色；超過門檻、沒有 Session、斷線或重連中時自動回到數量模式。
- **Done 小計數（Done Count）**：設定開啟後，選單列在 Idle 之後多顯示 `✓ n`，例如 `⚒ 3  ✋ 2  💤 1  ✓ 2`；數量為 0 時與其他類別一樣依「固定顯示 0 數量」決定是否顯示。

## 設定

- **App Settings**：使用者偏好設定的可觀察模型（`AppSettings`），包含「固定顯示 0 數量」（`alwaysShowZeroCounts`）、「顯示 Done 小計數」（`showDoneCount`），排序規則（`sortRule`）、動畫開關（`animationsEnabled`）、低干擾提醒（`lowDistractionAlerts`），以及選單列模式（`menuBarMode`）。模型只透過 `MenuBarSummary(snapshot:settings:)`、`SessionListModel(snapshot:settings:)` 與 `ApprovalAlertTracker.observe(needsApprovalCount:settings:now:)` 接收設定值，不自行讀取偏好儲存。
- **動畫開關（Animations Enabled）**：關閉後 Popover 角色只畫靜態姿勢，`CharacterMotion` 的循環與過渡一律為 nil，效果等同系統 Reduce Motion。預設開。
- **低干擾提醒（Low-Distraction Alert）**：設定開啟時，待核准（Needs Approval）數量比上一次觀察**增加**，選單列短暫強調約 3 秒後恢復（文字加粗、SF Symbol 跳一次），不閃爍、不循環、不使用音效或系統通知。數量減少或不變不觸發；設定關閉時永不觸發並清除進行中的強調；第一次觀察只記下基準數量。判斷由純值 `ApprovalAlertTracker` 負責（輸出 `alertUntil`，時間可注入），App 的 `MenuBarAlertModifier` 只負責套用與到期還原。預設開。
- **Settings Store**：設定的鍵值儲存介面（`SettingsStore`）。正式環境用 `UserDefaultsSettingsStore`（macOS 標準使用者偏好），測試用 `InMemorySettingsStore`；設定改動即時寫入，`AppSettings` 初始化時從中讀回，因此重啟後保留。

## Popover 清單

- **Session List Model**：由 Store snapshot 推導出的 Popover 純值清單模型（`SessionListModel`），包含固定標題 `IdleVillager`、Agent 總數、Workspace → Tab → 列的三層群組，以及底部資訊區。畫面只渲染它，不自行推論狀態或排序。
- **列（Row）**：清單中代表一個 Agent Session 的一列，以 `agentSessionID` 為 id，帶有 agentKind、displayName、paneLabel、正規化狀態、狀態圖示（⚒ ✋ ✓ 💤 ! ?）、狀態短文字（幹活中、等核准、完成、閒置、錯誤、訊號不足）與可選的補充說明（`detail`，目前是衝突描述）。
- **清單優先度（Priority Order）**：Needs Approval > Error > Done > Working > Idle > Unknown。列依此排序；Tab 與 Workspace 群組依內含的最高優先度（`topState`）排序，所以急件所在的群組會浮到最上方。同優先度時依名稱（數字以數值比較）再依 ID 排序。
- **排序規則（Sort Rule）**：Popover 清單的排序方式（`SortRule`），由 `SessionListModel(snapshot:sortRule:)` 套用，預設 `priority`。`priority` 即上述清單優先度；`workspaceName` 讓 Workspace 與 Tab 依名稱排序（數字以數值比較，同名再依 ID），列仍依優先度；`fixed` 讓 Workspace、Tab、列都依穩定 ID 的字串順序排序，是來源順序的近似，不因狀態改變而移動。
- **來源描述（Source Description）**：Adapter 提供、給使用者看的來源名稱（`HerdrAdapter.sourceDescription`，用字集中在 `SourceDescription`）。Session Store 放進 `StoreSnapshot.sourceDescription`，Footer 的 `sourceName` 直接採用，清單模型不寫死來源。已在使用者環境驗證過 Herdr API 的 Adapter 回報「Herdr」（`SourceDescription.herdr`）；`FakeHerdrAdapter` 回報「示範資料」（`SourceDescription.demo`）。未驗證的實作不得回報「Herdr」，因此示範模式下 Footer 是「來源：示範資料 · 已連線」，不會出現「Herdr · 已連線」。來源名稱只出現在 Footer，不出現在標題。
- **底部資訊區（Footer）**：Popover 底部的來源與連線資訊，包含來源描述、連線狀態文字（已連線、已斷線、重新連線中）與最後成功更新時間。
- **最後更新文字（Last Updated Text）**：`Footer.lastUpdatedText(now:)` 以注入的當下時間產生相對時間文字，例如「最後更新：3 分鐘前」；未滿 10 秒為「剛剛」，從未成功更新為「尚未成功更新」。
- **過期提示（Stale Notice）**：斷線或重連中、且曾成功更新過時，Footer 的 `staleNotice` 為「資料可能已過期，以上清單為最後一次成功更新的內容。」；已連線時為 nil。
- **空狀態（Empty State）**：清單沒有任何列時 `SessionListModel.emptyStateText` 的文字。已連線是零 Agent 狀態「目前沒有 Agent Session」，斷線或重連中是「未連線，沒有可顯示的 Session 資料」，兩者刻意不同；有列時為 nil。
- **Tab 收合**：使用者可收合 Tab 群組。收合狀態只存在 App 的 `SessionPopoverViewModel`，不在純值模型中，重啟後不保留。

## 小村民角色

- **Agent 種類（Agent Kind）**：`AgentKind` enum，值為 claude、codex、gemini、generic。由 Adapter 的 agentKind 原始字串以 `AgentKind(rawAgentKind:)` 對應，大小寫不敏感、底線與連字號視為相同（例如 `claude-code`、`openai-codex`、`codex-cli`、`gemini-cli`）；無法對應者為 generic。只收常見的明確值，不以 `anthropic`、`openai`、`google` 等廠商前綴猜測。
- **Character Presentation**：輸入正規化狀態、前一狀態與 Reduce Motion 開關，輸出角色呈現的純值（`CharacterPresentation`），包含姿勢、圖層與可選的過渡。畫面只依它繪製，不自行推論狀態。
- **姿勢（Pose）**：每種正規化狀態恰好對應一種靜態姿勢（`CharacterPose`）：Working 幹活（`working`）、Needs Approval 舉手（`raisingHand`）、Done 交工（`delivering`）、Idle 躺平（`lyingDown`）、Error 警示（`alert`）、Unknown 疑惑（`puzzled`）。每種姿勢都有不依賴動畫的完整靜態版本。
- **圖層（Layers）**：角色分成本體（body）、手（hands）、腳（feet）、道具（prop）、表情（face）、特效（effect）六層（`CharacterLayers`）。每層以 SF Symbol 名稱或 SwiftUI Shape 描述（`CharacterLayer`），本體一定存在，其他層為 nil 表示該姿勢不畫。Error 與 Unknown 不使用旗子、星光等成功類圖像。
- **品牌本體（Brand Body）**：角色本體要畫成品牌標誌還是 Generic 小村民（`BrandBody`）。`.asset(name:)` 指向 App resource bundle 內的素材名稱（`claude-logo`、`codex-logo`、`gemini-logo`，對應只定義在 `BrandBody.assetName(for:)`），`.generic` 是圓形的 Generic 本體。由純函式 `BrandBody.resolve(agentKind:isAssetAvailable:)` 決定，結果放在 `CharacterPresentation.brandBody`。品牌本體只辨識 Agent 種類：以原色繪製，不隨狀態改色、不拉伸、不旋轉、不疊表情；狀態只由手、腳、道具與特效表現。素材放置規範見 `Sources/IdleVillagerApp/Resources/Brands/README.md`。
- **備援（Fallback）**：品牌素材不存在或無法載入時，角色本體自動改用 Generic 小村民，不顯示破圖。generic 種類一律是 Generic 本體。專案不附第三方品牌素材，因此目前所有角色都走備援。
- **角色細節（Character Detail）**：依角色尺寸決定要畫多少圖層（`CharacterDetail`）。18 pt 以下為 `bodyOnly`，只畫主標誌（本體）；更大為 `full`，畫全部圖層。
- **過渡（Transition）**：狀態轉換時可選的一次性過渡（`CharacterTransition`）。Working 轉 Done 為 `celebrateOnce`（慶祝一次後維持交工姿勢）；其他狀態轉 Idle 為 `slowToIdle`（緩慢過渡）；其他轉換、沒有前一狀態（Session 第一次出現）或系統 Reduce Motion 開啟時沒有過渡。過渡只是描述，動畫由 App 層實作。過渡的動畫參數為 `CharacterTransitionParameters`：`celebrateOnce` 約 0.5 秒跳起再落下一次；`slowToIdle` 約 0.8 秒從半透明淡入躺平姿勢，不跳。
- **循環動作（Loop）**：姿勢持續播放的低干擾動作（`CharacterLoop`），只描述節奏與幅度（`CharacterLoopParameters`：週期、實際在動的時間、位移比例、擺動角度）。幹活為 `workingBob`（每 1.2 秒平穩上下跳動並擺動）；舉手為 `raisedHandSway`（每 4 秒晃一次，其餘時間靜止；週期不小於 3 秒是「不閃爍」的量化定義）；躺平為 `idleZzz`（每 6 秒浮出一個 Zzz）。交工、警示、疑惑沒有循環：交工只在過渡時跳一次，Error 是靜態警示，Unknown 不需動畫。
- **Character Motion**：輸入姿勢、過渡、系統 Reduce Motion 與使用者動畫開關（`animationsEnabled`），輸出循環動作與過渡的純值（`CharacterMotion`）。Reduce Motion 開啟或動畫關閉時兩者一律為 nil，畫面只畫靜態姿勢。動畫只在 Popover 的角色上播放，選單列不播放。

## 其他

- **isStale**：表示某個 Session 的資料已經不新鮮的旗標（`StoreSession.isStale`）。以該 Session 的 `updatedAt` 與上次成功讀取快照的時間兩者較晚者為基準，超過過期門檻（`staleThreshold`，預設 60 秒，可注入）時為 true；Adapter 回報斷線或重連中時，所有 Session 一律為 true。Store 在處理每個事件時重算，沒有事件時由 App 定期呼叫 `refreshStaleness()`。過期的列在狀態短文字後加上「（過期）」，例如「幹活中（過期）」，並帶 `isStale` 欄位。
- **重連同步（Reconnect Resync）**：Adapter 送出 `connectionChanged(.connected)` 時，Session Store 重新讀取一次完整快照，以補上斷線期間錯過的變更；讀取成功才轉為 connected 並更新最後成功更新時間，失敗則維持 disconnected、保留上次清單且全部過期。
- **事件訂閱優先、輪詢備援**：Adapter 取得變更的方式。來源支援事件訂閱時優先訂閱，否則由 Adapter 內部輪詢並合成同樣的事件；選擇與輪詢間隔都封裝在 Adapter 內，Store 以上不感知差異。
- **Focus**：使用者點擊一列後，把來源對應視窗帶到前景並聚焦到指定 Pane 的動作；結果是成功，或帶明確原因的失敗。尚未驗證的 Fake Adapter 不得回報成功：`FakeHerdrAdapter` 預設失敗原因是 `FocusFailureReason.demoMode`，`FocusFailure.message` 與 Popover 頂部文字都是「示範模式無法切回」，Popover 保持開啟。測試要模擬真實成功或其他失敗時，必須明確傳入 `FocusResult`。
- **Focus Coordinator**：處理 Focus 流程的可觀察物件（`FocusCoordinator`）。以列的 `AgentSessionID` 與 `PaneID`（不用清單索引）先向 Session Store 的 snapshot 確認目標仍存在且 Pane 相符；不存在就不呼叫 Adapter，直接回傳「目標已不存在」；存在才呼叫 Adapter 的 focus。結果為 `FocusOutcome`（成功，或帶 `FocusFailure` 的失敗）。`FocusFailure.message` 是使用者可讀原因；`FocusFailure.bannerText` 是 Popover 頂部顯示的完整文字（一般失敗為「無法切回：」加上原因，示範模式就是「示範模式無法切回」）。最近一次失敗公開在 `lastFailure` 供 Popover 頂部顯示，成功時清空。
- **Adapter**：把外部資料來源（目前是 Herdr）轉成本專案資料模型的元件，介面為 `HerdrAdapter` protocol；`FakeHerdrAdapter` 是記憶體內的實作。
- **Seam**：可以在不改動呼叫端的情況下替換實作的介面接縫。本專案的測試 seam 是 `HerdrAdapter`（所有 Session 資料都透過 Fake Adapter 餵入）與 `SettingsStore`（偏好儲存以記憶體內實作替換）。
