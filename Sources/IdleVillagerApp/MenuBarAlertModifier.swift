import SwiftUI
import IdleVillagerCore

/// 低干擾提醒的選單列強調：待核准數量增加且設定開啟時，選單列文字短暫加粗，
/// 其中的 SF Symbol（例如斷線圖示或角色）跳動一次；到期後恢復原樣。
///
/// 何時強調完全由 `ApprovalAlertTracker` 決定，這裡只負責套用與到期還原。不閃爍、不循環、不使用音效或系統通知。
struct MenuBarAlertModifier: ViewModifier {
    let needsApprovalCount: Int
    let settings: AppSettings

    @State private var tracker = ApprovalAlertTracker()
    @State private var isEmphasized = false

    func body(content: Content) -> some View {
        content
            .fontWeight(isEmphasized ? .bold : nil)
            // value 只在提醒觸發時改變，因此只跳一次。
            .symbolEffect(.bounce, value: tracker.alertUntil)
            .onAppear {
                // 第一次只記下基準數量，啟動當下已有的待核准不觸發。
                tracker.observe(needsApprovalCount: needsApprovalCount, settings: settings, now: .now)
            }
            .onChange(of: needsApprovalCount) { _, newCount in
                tracker.observe(needsApprovalCount: newCount, settings: settings, now: .now)
                isEmphasized = tracker.isAlerting(at: .now)
            }
            .onChange(of: settings.lowDistractionAlerts) { _, _ in
                tracker.observe(needsApprovalCount: needsApprovalCount, settings: settings, now: .now)
                isEmphasized = tracker.isAlerting(at: .now)
            }
            .task(id: tracker.alertUntil) {
                guard let alertUntil = tracker.alertUntil else { return }
                let remaining = alertUntil.timeIntervalSinceNow
                if remaining > 0 {
                    try? await Task.sleep(for: .seconds(remaining))
                }
                guard !Task.isCancelled else { return }
                isEmphasized = tracker.isAlerting(at: .now)
            }
    }
}

extension View {
    /// 套用低干擾提醒（見 `MenuBarAlertModifier`）。
    func approvalAlert(needsApprovalCount: Int, settings: AppSettings) -> some View {
        modifier(MenuBarAlertModifier(needsApprovalCount: needsApprovalCount, settings: settings))
    }
}
