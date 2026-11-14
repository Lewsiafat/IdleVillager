# README 翻新：文案重寫、截圖重拍、加入介紹影片 — Walkthrough

- **分支:** `docs/readme-refresh`
- **日期:** 2026-11-15

## 變更摘要

重寫中英文兩份 README 的文案，開頭改從「用 Herdr 跑多個 Agent 時，一切到別的視窗就看不到它們的狀況」這個痛點講起，語氣改成作者第一人稱。舊的主截圖與示範 GIF 換成新錄的門面動圖與清單截圖，並加入一段 11 秒、含英文字卡的介紹影片。這次沒有改 App 的程式。

## 修改的檔案

- `README.zh-TW.md`：開頭、產品介紹、功能說明全部重寫；功能說明整理成「先看數量、再看是誰、點一下回去」三個步驟；新增「幾件我比較堅持的事」段落；「最近更新」改為 v0.3.3；圖片換成新素材並加入影片網址。安裝、更新與移除的指令沒有變動。
- `README.md`：依中文版定稿重寫的英文版，語氣一致但不是逐字翻譯；其餘變更與中文版相同。
- `docs/images/hero.gif`：新增。門面動圖，11 秒，800 × 668 像素，約 1 MB。
- `docs/images/popover.png`：新增。清單截圖，同時有等待核准、工作中、完成與閒置四種狀態。
- `docs/images/hero.png`、`docs/images/demo.gif`：移除，README 不再使用。
- `CHANGELOG.md`：`[Unreleased]` 新增兩筆紀錄（文案改寫、圖片重拍）。
- `specs/readme-refresh.md`：本任務的規格與任務清單。

介紹影片的 MP4 沒有放進 repo。GitHub 的 README 只會把上傳到 GitHub 附件的影片顯示成播放器，所以影片上傳在 issue #59，README 裡放的是附件網址。

## 技術細節

### 文案

中文版先寫，再用 `speak-human-tw` skill 檢查，查到八處並全部套用。其中兩處是初稿裡替作者編的經歷細節（「等了二十分鐘」「另外兩個做完很久」），改成不含具體數字的寫法；另有兩處是初稿多加的事實（「騰出位置就會出現」「v0.3.2 或更早版本」），改回與原 README 和 `CHANGELOG.md` 一致的說法。

功能說明保留三個粗體開頭的段落。三段式排比通常是需要避免的寫法，但這三步對應產品規格裡的三個動作，所以保留。

### 錄製環境

畫面不能露出真實的專案名稱，所以沒有用使用者平常的 Herdr session，而是另外開一個獨立的 session：

- 用 `herdr --session ivdemo` 啟動具名 session，它有自己的 server 與 socket，不會影響原本的 workspace。
- 以環境變數 `IDLEVILLAGER_HERDR_SOCKET` 讓一份另外建置的 IdleVillager（v0.3.3）連到這個 session。偏好設定用啟動參數覆寫（`-translucentPopoverBackground NO -language en -showDoneCount NO`），只對這個執行個體有效，不會寫進使用者的設定。
- session 裡有三個 workspace、六個 Claude Code。等待核准的那一個獨佔一個 tab，跳轉後整個畫面只有核准提示。第一版把它和一個工作中的 Agent 並排在同一個 tab，跳轉後看起來像跳到別的 session，所以重錄。
- 示範 Agent 以 `--setting-sources project,local` 啟動，不套用個人設定。原因有兩個：個人設定允許了指令與寫檔，Agent 不會停在核准提示；個人設定把語言固定為繁體中文，清單裡的 session 標題會是中文。
- 沒有使用 App 的示範模式（`IDLEVILLAGER_DEMO=1`）。示範模式下點擊 session 不會真的跳轉，拍不到第三個鏡頭。

### 錄製與剪接

- 螢幕錄影用 `screencapture -V`，只錄螢幕右上方 880 × 660 pt 的範圍。
- 滑鼠的移動與點擊由一支用 `CGEvent` 寫的小工具執行，需要 macOS 的「輔助使用」權限。
- 「正在做別的事」的視窗是一支自製的小程式，用 `WKWebView` 顯示一頁本機的文件。沒有用 Chrome，原因見下一節。
- 剪接用 `ffmpeg`：`drawbox` 以選單列的底色遮掉其他 App 的圖示與時鐘，`pad` 在畫面下方加一條深色區域放字卡，`drawtext` 畫三段會淡入淡出的字卡。動圖用 `palettegen` 與 `paletteuse` 轉出。

腳本與原始檔都在 `temp/readme-refresh/`（`temp/` 不進 repo）：`setup.sh` 建立示範環境，`take.sh` 錄一次，`edit.sh` 剪成成品。只改字卡或剪接點時，重跑 `edit.sh` 即可，不用重錄。

### 錄製時發現的產品問題

這三項與本任務無關，沒有修改程式，另外記在 `specs/readme-refresh.md` 最後：

- 選單列同時顯示四種數量時，項目寬度約 156 pt，在有瀏海的 MacBook 上會整個被藏起來。
- 前景 App 的選單很長時（例如 Chrome），選單列項目也會被擠到瀏海後面而消失。這就是自製文件視窗取代 Chrome 的原因。
- 系統是深色模式、清單後方是亮色視窗時，清單底部「Settings…」與「Quit IdleVillager」兩個按鈕的字幾乎看不見。所以文件視窗用了深色。

### 尚未確認

兩份 README 的圖片、影片播放器與連結在 GitHub 上是否正常顯示，要 push 之後才能確認。
