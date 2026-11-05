import AppKit
import IdleVillagerCore

/// 以 `NSRunningApplication` 把執行 Herdr 客戶端的終端機 App（例如 Ghostty）帶到前景。
///
/// 沿每條程序鏈往上，找到第一個有 bundle identifier 的 App 就啟用它。
struct AppKitTerminalActivator: TerminalActivator {
    func activate(processAncestries: [[pid_t]]) async -> Bool {
        await MainActor.run {
            for chain in processAncestries {
                for pid in chain where pid > 1 {
                    guard
                        let app = NSRunningApplication(processIdentifier: pid),
                        app.bundleIdentifier != nil
                    else { continue }
                    // macOS 14 起改為協作式啟用：本 App 先把啟用權讓給目標 App，目標 App 才能被帶到前景。
                    // `activateIgnoringOtherApps` 在 macOS 14 已棄用且沒有作用，因此不使用。
                    NSApplication.shared.yieldActivation(to: app)
                    if app.activate(options: [.activateAllWindows]) { return true }
                }
            }
            return false
        }
    }
}
