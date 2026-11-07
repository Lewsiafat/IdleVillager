import SwiftUI
import IdleVillagerCore

/// 低干擾提醒的選單列強調：待核准數量增加且設定開啟時，選單列短暫強調待核准項目，到期後恢復原樣。
///
/// 數量模式與少量角色模式的選單列都是 `ImageRenderer` 畫出的圖片，所以強調程度透過 `menuBarAlertEmphasis`
/// 環境值交給 `MenuBarCountsLabel` 與 `MenuBarCharactersLabel`，由它們在產圖時以 `menuBarEmphasisBackground`
/// 畫出同一種圓角底色：數量模式強調等核准那一格，角色模式強調待核准角色。
/// 這裡另外套用的加粗與 SF Symbol 跳動只對未產圖的文字或圖示有效，數量模式與角色模式都不依賴它們。
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
    /// 目前選單列的提醒強調程度，由 `MenuBarAlertModifier` 設定；數量模式與少量角色模式產圖時讀取。
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

/// 選單列提醒強調的共用樣式：圓角底色填滿（primary 色、低透明度）。
private struct MenuBarEmphasisBackground: ViewModifier {
    let highlighted: Bool

    /// 底色的不透明度；選單列圖片是 template，最終顏色由系統依明暗外觀決定。
    static let fillOpacity: Double = 0.25

    func body(content: Content) -> some View {
        content
            // 不論是否強調都固定保留內距，強調開始與結束時寬度不變，選單列不會跳動。
            .padding(.horizontal, 2)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.primary.opacity(highlighted ? Self.fillOpacity : 0))
            }
    }
}

extension View {
    /// 套用選單列提醒強調的圓角底色（見 `MenuBarEmphasisBackground`）；數量模式與少量角色模式共用。
    func menuBarEmphasisBackground(_ highlighted: Bool) -> some View {
        modifier(MenuBarEmphasisBackground(highlighted: highlighted))
    }
}
