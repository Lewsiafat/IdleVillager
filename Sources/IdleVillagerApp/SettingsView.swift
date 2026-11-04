import AppKit
import SwiftUI
import IdleVillagerCore

/// 設定視窗內容，使用 macOS 標準的分組表單樣式。
struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("選單列") {
                Picker("選單列模式", selection: $settings.menuBarMode) {
                    Text("數量模式").tag(MenuBarMode.counts)
                    Text("少量角色模式").tag(MenuBarMode.fewCharacters)
                }
                Toggle("固定顯示數量為 0 的類別", isOn: $settings.alwaysShowZeroCounts)
                Toggle("顯示已完成小計數（✓）", isOn: $settings.showDoneCount)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Popover 底部的設定入口。App 只出現在選單列，沒有應用程式選單，因此開啟設定前先把 App 帶到前景。
struct SettingsEntryButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("設定…") {
            NSApplication.shared.activate()
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
        .padding([.horizontal, .bottom], 12)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
