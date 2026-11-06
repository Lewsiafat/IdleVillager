import SwiftUI
import IdleVillagerCore

/// 低干擾提醒的選單列強調：待核准數量增加且設定開啟時，選單列文字短暫加粗，
/// 其中的 SF Symbol（例如斷線圖示）跳動一次；到期後恢復原樣。
///
/// 少量角色模式的選單列是 `ImageRenderer` 畫出的圖片，加粗與跳動對它無效，
/// 所以強調程度也透過 `menuBarAlertEmphasis` 環境值交給 `MenuBarCharactersLabel`，由它在產圖時畫出外框。
///
/// 何時強調完全由 `ApprovalAlertTracker` 決定，這裡只負責套用與到期還原。不閃爍、不循環、不使用音效或系統通知。
struct MenuBarAlertModifier: ViewModifier {
    let needsApprovalCount: Int
    let settings: AppSettings

    @State private var tracker = ApprovalAlertTracker()
    @State private var emphasis: MenuBarAlertEmphasis = .none

    func body(content: Content) -> some View {
        content
            .fontWeight(emphasis == .emphasized ? .bold : nil)
            // value 只在提醒觸發時改變，因此只跳一次。
            .symbolEffect(.bounce, value: tracker.alertUntil)
            .environment(\.menuBarAlertEmphasis, emphasis)
            .onAppear {
                // 第一次只記下基準數量，啟動當下已有的待核准不觸發。
                tracker.observe(needsApprovalCount: needsApprovalCount, settings: settings, now: .now)
            }
            .onChange(of: needsApprovalCount) { _, newCount in
                tracker.observe(needsApprovalCount: newCount, settings: settings, now: .now)
                emphasis = tracker.emphasis(at: .now)
            }
            .onChange(of: settings.lowDistractionAlerts) { _, _ in
                tracker.observe(needsApprovalCount: needsApprovalCount, settings: settings, now: .now)
                emphasis = tracker.emphasis(at: .now)
            }
            .task(id: tracker.alertUntil) {
                guard let alertUntil = tracker.alertUntil else { return }
                let remaining = alertUntil.timeIntervalSinceNow
                if remaining > 0 {
                    try? await Task.sleep(for: .seconds(remaining))
                }
                guard !Task.isCancelled else { return }
                emphasis = tracker.emphasis(at: .now)
            }
    }
}

// 只有 Command Line Tools 時沒有 SwiftUI 的 macro plugin，無法使用 `@Entry`，改用傳統的 EnvironmentKey。
private struct MenuBarAlertEmphasisKey: EnvironmentKey {
    static let defaultValue: MenuBarAlertEmphasis = .none
}

extension EnvironmentValues {
    /// 目前選單列的提醒強調程度，由 `MenuBarAlertModifier` 設定；少量角色模式產圖時讀取。
    var menuBarAlertEmphasis: MenuBarAlertEmphasis {
        get { self[MenuBarAlertEmphasisKey.self] }
        set { self[MenuBarAlertEmphasisKey.self] = newValue }
    }
}

extension View {
    /// 套用低干擾提醒（見 `MenuBarAlertModifier`）。
    func approvalAlert(needsApprovalCount: Int, settings: AppSettings) -> some View {
        modifier(MenuBarAlertModifier(needsApprovalCount: needsApprovalCount, settings: settings))
    }
}
