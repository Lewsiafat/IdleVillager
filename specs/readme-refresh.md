# README 翻新：文案重寫、截圖重拍、加入介紹影片

- **分支:** `docs/readme-refresh`
- **基底分支:** `main`
- **日期:** 2026-11-15

## 描述
重寫 README 的文案讓它更吸引人、讀起來不像 AI 寫的，換掉不好看的截圖，並加入一段產品介紹影片。

目前的 README 有三個問題。第一，主截圖 `docs/images/hero.png` 裡七個 Agent 全部是 Idle，看不出「有人在等你核准」這個最有價值的情境；畫面裡是真實的專案名稱，版號還停在 v0.1.1，選單列也拍到了其他 App 的圖示。第二，文案是功能清單式的寫法，沒有講出使用者的痛點。第三，只有一段 7 秒的 `demo.gif`，沒有介紹影片。

這次只動 `README.md`、`README.zh-TW.md` 與 `docs/images/` 裡的素材，不改 App 的程式邏輯。

## 已確認的決定

- **要講的痛點：** 用 Herdr 同時跑多個 Agent 時，使用者一切到別的視窗做其他事情，Herdr 被蓋住，就看不到各個 Agent 的運作狀況。IdleVillager 把狀態放在選單列，而選單列不管切到哪個 App 都看得到。文案與影片都要圍繞這一點。
- **文案語氣：** 作者第一人稱，帶點幽默。從上面的痛點情境開場（交代完工作切去別的視窗，回來才發現有 Agent 等核准等了很久），再帶出《世紀帝國》閒置村民的靈感，最後才是功能與安裝。
- **影片形式：** 動圖與 MP4 兩者都要。README 最上方放會自動播放的短動圖當門面；下方放 MP4 介紹影片。
- **影片長度：** 10 到 20 秒。
- **錄製方式：** 由 Claude 寫腳本自動錄製與剪接，使用者看成品。
- **MP4 的放置方式：** GitHub 的 README 不能直接播放 repo 裡的 MP4，只有上傳到 GitHub 附件（把檔案拖進 issue 或 PR 編輯框後得到的網址）才會顯示成播放器。所以 MP4 檔案不放進 repo，由使用者上傳一次取得網址，再把網址寫進 README。

## 素材規劃

| 素材 | 檔案 | 資料來源 | 用途 |
| --- | --- | --- | --- |
| 門面動圖 | `docs/images/hero.gif` | 真實 Herdr 加示範用 workspace | README 最上方，自動播放 |
| 清單截圖 | `docs/images/popover.png` | 示範模式 | 展示四種狀態同時出現的清單 |
| 介紹影片 | 不進 repo，上傳 GitHub 附件 | 與門面動圖同一批畫面 | 加上字卡的 10 到 20 秒完整版 |

示範模式是指以環境變數 `IDLEVILLAGER_DEMO=1` 啟動 App，這時 App 會顯示虛構資料（3 個 Working、2 個 Needs Approval、1 個 Idle、1 個 Done），不會露出真實的專案名稱。示範模式下點擊 session 不會真的跳轉，所以「一鍵切回」的鏡頭必須連真實的 Herdr 來拍，拍攝時使用名稱乾淨的示範用 workspace。

介紹影片的三個鏡頭對應產品的一句話定位：先看選單列的數量，再展開清單找到等待核准的那一個，最後點一下跳回 Herdr 對應的 pane。開場畫面要是「使用者正在別的 App（例如瀏覽器）裡，Herdr 不在畫面上」，這樣才看得出選單列解決了什麼問題。

錄製腳本與原始檔放在 `temp/readme-refresh/`（`temp/` 已被 `.gitignore` 排除，不會進 repo）。

## 任務清單

### 文案
- [x] 重寫 `README.zh-TW.md` 的開頭、產品介紹與功能重點：第一人稱、從痛點開場、帶出閒置村民的靈感
- [x] 用 `speak-human-tw` skill 檢查中文版，去除 AI 味、中國用語與半形標點（查到八處，全部套用）
- [x] 依中文版定稿重寫 `README.md`（英文版），語氣一致，不逐字翻譯
- [x] 安裝、更新與移除段落的指令與事實內容保持不變，只調整語氣
- [x] 「最近更新」段落從 v0.3.0 更新到目前的 v0.3.3
- [x] 商標段落保留，內容不刪減

### 截圖
- [x] 擷取清單展開的畫面，存為 `docs/images/popover.png`（實際做法：沒有用示範模式，改用獨立的 Herdr session 加真實的 Agent 來拍，畫面與影片一致）
- [x] 截圖只保留 IdleVillager 的選單列項目與清單，其他 App 的選單列圖示以底色遮掉
- [x] 確認截圖裡顯示的版號是目前版本（v0.3.3），且沒有真實專案名稱
- [x] 移除不再使用的 `docs/images/hero.png` 與 `docs/images/demo.gif`

### 影片與動圖
- [x] 建立名稱乾淨的示範環境：獨立的 Herdr session `ivdemo`，三個 workspace，畫面同時有 Working、Needs Approval、Done 與 Idle 的 Agent
- [x] 寫錄製腳本，錄下三個鏡頭：選單列數量、展開清單、點擊後跳回 Herdr 對應的 pane
- [x] 用 `ffmpeg` 剪接成 11 秒的 MP4，加上三段英文字卡
- [x] 從同一批畫面輸出門面動圖 `docs/images/hero.gif`（約 1 MB）
- [x] 使用者確認成品後，由使用者把 MP4（`temp/readme-refresh/out/idlevillager-intro.mp4`）上傳到 GitHub 附件並提供網址
- [x] 把 MP4 網址寫進兩份 README（上傳在 issue #59）
- [x] 錄製結束後移除示範用的 session 與視窗

### 檢查
- [x] 產品名稱一律寫 `IdleVillager`
- [x] 截圖與影片不含《世紀帝國》官方美術，也不含第三方品牌標誌（角色顯示的是 Generic 小村民）
- [x] 文案不聲稱 Herdr API 已通過驗證
- [ ] 兩份 README 的圖片連結、語言切換連結與 `CHANGELOG.md` 連結在 GitHub 上都能正常顯示（要 push 之後才能確認）
- [x] 在 `CHANGELOG.md` 的 `[Unreleased]` 記錄 README 翻新

## 錄製過程中發現、與本任務無關的產品問題

- 選單列同時顯示四種數量（工作中、等待核准、閒置、完成）時，項目寬度約 156 pt，在有瀏海的 MacBook 上會整個被藏起來。錄影時是關掉完成數量才顯示得出來。
- 前景 App 的選單很長時（例如 Chrome），IdleVillager 的選單列項目也會被擠到瀏海後面而消失。
- 系統是深色模式、而清單後方是亮色視窗時，清單會變成偏灰的半透明色，底部「Settings…」與「Quit IdleVillager」兩個按鈕的字幾乎看不見。
