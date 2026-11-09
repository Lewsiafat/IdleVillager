import SwiftUI
import IdleVillagerCore

/// 設定視窗中的「清單與提醒」區段：排序規則、動畫開關與低干擾提醒。
struct BehaviorSettingsSection: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Section(L10n.text(.settingsBehaviorSection)) {
            Picker(L10n.text(.settingsSortRule), selection: $settings.sortRule) {
                ForEach(SortRule.allCases, id: \.self) { rule in
                    Text(Self.title(of: rule)).tag(rule)
                }
            }
            Toggle(L10n.text(.settingsAnimations), isOn: $settings.animationsEnabled)
            Toggle(isOn: $settings.lowDistractionAlerts) {
                Text(L10n.text(.settingsLowDistractionAlerts))
                Text(L10n.text(.settingsLowDistractionAlertsDetail))
                    .font(.caption)
            }
        }
    }

    private static func title(of rule: SortRule) -> String {
        switch rule {
        case .priority: L10n.text(.settingsSortPriority)
        case .workspaceName: L10n.text(.settingsSortWorkspaceName)
        case .fixed: L10n.text(.settingsSortFixed)
        }
    }
}
