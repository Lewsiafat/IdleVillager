import Foundation

/// Popover footer 顯示的 App 版號文字。
///
/// 版號來自 `Info.plist` 的 `CFBundleShortVersionString`，由 `distribution/make-app.sh`
/// 從 `herdr-plugin.toml` 寫入。以 `swift run` 執行的開發版沒有 `Info.plist`，讀不到版號時顯示「開發版」。
public enum AppVersionLabel {
    /// 讀不到版號時顯示的文字。
    public static let developmentText = "開發版"

    /// 把 `CFBundleShortVersionString` 轉成顯示文字：有版號時為 `v<版號>`，nil 或空白時為「開發版」。
    public static func text(shortVersion: String?) -> String {
        guard let version = shortVersion?.trimmingCharacters(in: .whitespacesAndNewlines), !version.isEmpty else {
            return developmentText
        }
        return "v\(version)"
    }

    /// 給 VoiceOver 讀的完整說明。
    public static func accessibilityText(shortVersion: String?) -> String {
        let text = text(shortVersion: shortVersion)
        return text == developmentText ? "IdleVillager 開發版" : "IdleVillager 版本 \(text.dropFirst())"
    }
}
