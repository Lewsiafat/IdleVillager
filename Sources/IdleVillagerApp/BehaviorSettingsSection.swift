import SwiftUI
import IdleVillagerCore

/// 設定視窗中的「清單與提醒」區段：排序規則、動畫開關與低干擾提醒。
struct BehaviorSettingsSection: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Section("清單與提醒") {
            Picker("排序規則", selection: $settings.sortRule) {
                ForEach(SortRule.allCases, id: \.self) { rule in
                    Text(Self.title(of: rule)).tag(rule)
                }
            }
            Toggle("播放角色動畫", isOn: $settings.animationsEnabled)
            Toggle(isOn: $settings.lowDistractionAlerts) {
                Text("低干擾提醒")
                Text("待核准數量增加時，選單列短暫強調後恢復（數量模式文字加粗，少量角色模式待核准角色加框）；不使用音效或系統通知。")
            }
        }
    }

    private static func title(of rule: SortRule) -> String {
        switch rule {
        case .priority: "依優先度"
        case .workspaceName: "依 Workspace 名稱"
        case .fixed: "固定順序"
        }
    }
}
