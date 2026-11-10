# 修正半透明背景沒有作用 — Walkthrough

- **分支:** `fix/translucent-popover`
- **日期:** 2026-11-10

## 變更摘要
0.2.0 加入的「清單使用半透明背景」開啟後，清單看起來仍然不透明。原因是 SwiftUI 在選單列視窗裡另外畫了一層不透明的底色，蓋住了模糊效果。現在半透明時會把這層底色藏起來，並替 footer 墊一層較濃的底色，讓按鈕在亮色桌面上也看得清楚。

## 修改的檔案
- `Sources/IdleVillagerApp/PopoverBackground.swift`：`BehindWindowMaterial` 改用新的 `TranslucentBackdropView`，在畫面上時藏起排在它下方的全尺寸 SwiftUI 底色 View，移除時還原。
- `Sources/IdleVillagerCore/PopoverBackground.swift`：新增 `footerBackingOpacity`，半透明時為 0.85，不透明時為 nil。
- `Sources/IdleVillagerApp/SessionPopoverView.swift`：footer 依 `footerBackingOpacity` 墊底色。
- `Tests/IdleVillagerCoreTests/PopoverBackgroundTests.swift`：新增 footer 底色的測試。
- `CHANGELOG.md`：`[Unreleased]` 新增兩項 Fixed。

## 技術細節

**找出原因的方法。** 在 `NSVisualEffectView` 放進視窗後，把整個視窗的 View 樹印到檔案。結果顯示視窗本身不是不透明的（`isOpaque = false`、背景透明），但 `NSHostingView` 底下、排在我們的模糊層前面，有兩個和視窗一樣大的 `_NSGraphicsView`，底色分別是 50% 和 100% 不透明的深灰。subviews 陣列前面的 View 畫在下面，所以這兩層擋在桌面和模糊層之間。實驗版把它們設成 `isHidden` 後，使用者確認清單變成半透明。

**藏起底色的範圍。** `TranslucentBackdropView` 只處理同一個父 View 裡、排在自己的宿主 View 之前、而且大小等於父 View 的兄弟 View。清單內容排在後面，不會被動到。被藏起來的 View 會記下來，在 `dismantleNSView` 或離開視窗時還原，所以關掉設定或關閉清單後會回到原本的樣子。`layout()` 時會再檢查一次，處理清單改變高度時 SwiftUI 重建底色的情況。

**風險。** 這依賴 SwiftUI 內部的 View 結構，只在 macOS 14.6 實機確認過。如果之後的 macOS 改了結構，最壞情況是清單又變回不透明，不會閃退。macOS 15 以上有官方的 `.containerBackground(_:for: .window)`，但最低支援版本是 14，所以沒有採用。

**footer 底色。** footer 的按鈕使用系統的半透明淺色外框，用卡片的 0.5 底色時，在白色桌面上仍然太白，所以改成 0.85。footer 所在的 `SessionPopoverView` 自己設定 `popoverBackgroundStyle` 環境值，讀環境只會拿到上層的預設值，因此直接從設定計算樣式。

**驗證。** `swift test` 共 267 個測試通過。使用者在實機確認：開啟清單即為半透明、關閉再開仍正常、切換設定開關會即時切換、footer 按鈕在亮色桌面上看得清楚。
