# 待確認清單

## 使用者環境

- [ ] 使用 Herdr TUI 還是 Herdr Desktop？
- [ ] Herdr 版本號？
- [ ] 主要 Agent：Claude Code、Codex、Gemini CLI 的實際使用比例？
- [ ] 同時開啟 Session 的常見數量？

## 技術驗證

- [ ] 有哪些正式支援的狀態事件？
- [ ] 能否精準區分需要使用者批准和已完成？
- [ ] 能否在 Session 切換後可靠讓 macOS 視窗到前景？
- [ ] Agent / Pane / Tab 識別碼是否跨重新整理穩定？

## 視覺驗證

- [ ] 官方品牌 Logo 的可用格式與授權條件？
- [ ] 品牌主體要保留官方原貌，還是採用品牌旁邊搭配小角色？
- [ ] 選單列動畫是否只於有少量 Session 時開啟？
- [ ] Done / Error / Unknown 是否常駐顯示獨立小計數？

## 發佈

- [ ] `herdr plugin install` 的 `[[build]]` 在使用者電腦上能否成功建置？產物有沒有 quarantine 標記？
- [ ] `[[startup]]` 是否在 Herdr server 重啟後自動開啟 App？
- [ ] macOS 15 以上，ad-hoc 簽章的 App 是否仍會出現「強制打開」按鈕？
- [ ] 是否要申請 Apple Developer Program（年費 99 美元）以支援簽章與 notarization？

請先用實際 Herdr 環境確認以上內容；不要因為尚未確認而阻塞規格閱讀或其他可獨立開發的部分。
