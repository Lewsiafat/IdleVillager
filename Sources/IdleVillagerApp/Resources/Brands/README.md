# 品牌本體素材（Brands）

這個目錄放 Popover 小村民的品牌本體素材。專案**不附帶任何第三方品牌圖檔**，目前目錄裡只有這份說明；素材缺席時，所有 Agent 的角色本體都會自動備援為 Generic 小村民，不會顯示破圖。

## 放置位置與檔名

把素材直接放在本目錄，檔名（不含副檔名）必須完全符合下表，App 才找得到：

| Agent 種類 | 檔名 |
| --- | --- |
| Claude | `claude-logo.pdf`、`claude-logo.svg` 或 `claude-logo.png` |
| Codex | `codex-logo.pdf`、`codex-logo.svg` 或 `codex-logo.png` |
| Gemini | `gemini-logo.pdf`、`gemini-logo.svg` 或 `gemini-logo.png` |

查找順序是 PDF、SVG、PNG，找到第一個能載入的就使用。建議使用向量 PDF，因為它在 16 到 36 pt 之間縮放都不會模糊。`Package.swift` 以 `.process("Resources")` 把本目錄打包進 App 的 resource bundle，App 以 `Bundle.module` 查找。資源名稱的對應定義在 `BrandBody.assetName(for:)`，只有一處。

本專案以 Swift Package 建置，沒有 Xcode 的 `actool`，因此不使用 `.xcassets` asset catalog。

## 素材規格

- 只放各品牌的主標誌（圖案部分），不含文字商標，背景透明、正方形畫布、圖案置中。
- 必須在 16 到 18 pt 仍可辨識。小尺寸時 App 只畫本體，不畫手、腳、道具、表情與特效。
- App 以原色繪製，不套色（tint）、不拉伸、不旋轉，也不在標誌上疊加表情，因此素材本身必須同時適合深色與淺色模式。如果品牌規範提供深色與淺色兩種版本，請先確認規範允許哪一種用在兩種背景上。
- 不可自行繪製或修改品牌標誌，也不可使用仿冒品。

## 來源與使用規範（加入素材前必須補齊）

每加入一個檔案，就在下表補上一列。沒有可追溯來源與使用許可的素材不得加入。

| 檔名 | 官方來源網址 | 使用規範網址 | 取得日期 | 授權或許可說明 |
| --- | --- | --- | --- | --- |
| （尚無） | | | | |

素材授權的取得不在目前開發票的範圍內。
