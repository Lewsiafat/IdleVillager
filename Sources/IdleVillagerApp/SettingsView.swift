import AppKit
import SwiftUI
import IdleVillagerCore

/// 設定視窗內容，使用 macOS 標準的分組表單樣式。分組順序為選單列預覽、選單列、清單與提醒。
struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            MenuBarPreviewSection(settings: settings)
            Section("選單列") {
                Picker("選單列模式", selection: $settings.menuBarMode) {
                    Text("數量模式").tag(MenuBarMode.counts)
                    Text("少量角色模式").tag(MenuBarMode.fewCharacters)
                }
                Toggle("固定顯示數量為 0 的類別", isOn: $settings.alwaysShowZeroCounts)
                Toggle("顯示完成小計數", isOn: $settings.showDoneCount)
            }
            BehaviorSettingsSection(settings: settings)
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// 設定視窗頂部的「選單列預覽」：以示範資料依目前設定即時畫出選單列 label。
///
/// 直接重用 `MenuBarLabel`，排版與狀態判定都不在這裡重寫；示範快照由 `StoreSnapshot.menuBarPreview(for:)` 依模式挑選，
/// 讓少量角色模式的預覽確實畫出角色，而不是因 Session 數量達到門檻退回數量模式。
private struct MenuBarPreviewSection: View {
    let settings: AppSettings

    var body: some View {
        Section {
            HStack {
                Spacer()
                MenuBarLabel(snapshot: .menuBarPreview(for: settings.menuBarMode), settings: settings)
                    .frame(height: 22)
                    .padding(.horizontal, 10)
                    .background(.bar, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
                Spacer()
            }
            .padding(.vertical, 4)
        } header: {
            Text("選單列預覽")
        } footer: {
            Text("以示範資料呈現，實際內容依 Herdr 回報的 Agent 而定。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Popover footer 的設定入口，與「結束 IdleVillager」並排。App 只出現在選單列，沒有應用程式選單，因此開啟設定前先把 App 帶到前景。
struct SettingsEntryButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("設定…") {
            NSApplication.shared.activate()
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}
