import AppKit
import SwiftUI
import IdleVillagerCore

@main
struct IdleVillagerMenuBarApp: App {
    @State private var store: SessionStore
    @State private var focusCoordinator: FocusCoordinator
    @State private var settings = AppSettings(store: UserDefaultsSettingsStore())

    init() {
        // 以 Swift Package 執行檔啟動時沒有 Info.plist 的 LSUIElement，改用程式設定成只出現在選單列。
        NSApplication.shared.setActivationPolicy(.accessory)

        // 真實 Herdr Adapter 尚未驗證，先以 Fake Adapter 的示範快照啟動。
        // 預設來源是「示範資料」，focus 回傳示範模式失敗，不顯示「Herdr · 已連線」，也不假裝已切回。
        let adapter = FakeHerdrAdapter(snapshot: .demo)
        let store = SessionStore(adapter: adapter)
        _store = State(initialValue: store)
        _focusCoordinator = State(initialValue: FocusCoordinator(store: store, adapter: adapter))
        Task { await store.start() }
        // 沒有事件時也要讓久未更新的 Session 轉為過期，定期重新評估。
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                store.refreshStaleness()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            SessionPopoverView(snapshot: store.snapshot)
                .environment(focusCoordinator)
                .environment(settings)
            SettingsEntryButton()
        } label: {
            MenuBarLabel(snapshot: store.snapshot, settings: settings)
                .approvalAlert(needsApprovalCount: store.snapshot.counts.needsApproval, settings: settings)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings)
        }
    }
}

/// 選單列文字，完全由摘要模型決定；畫面不自行推論狀態。因觀察 `AppSettings`，設定改動時即時重繪。
struct MenuBarLabel: View {
    let snapshot: StoreSnapshot
    let settings: AppSettings

    var body: some View {
        // 少量角色模式且 Session 數量低於門檻時顯示角色；其餘情況（含斷線、0 個、達到或超過門檻）一律回到數量模式。
        if case .characters(let items) = MenuBarCharacterMode(snapshot: snapshot, settings: settings).display {
            MenuBarCharactersLabel(items: items)
        } else {
            let summary = MenuBarSummary(snapshot: snapshot, settings: settings)
            Group {
                // 斷線或重連中只顯示斷線圖示，不顯示任何數字。
                if let symbolName = MenuBarSummaryFormatter.symbolName(for: summary) {
                    Image(systemName: symbolName)
                } else {
                    Text(MenuBarSummaryFormatter.text(for: summary))
                }
            }
            .accessibilityLabel(accessibilityText(for: summary))
        }
    }

    private func accessibilityText(for summary: MenuBarSummary) -> String {
        switch summary.mode {
        case .disconnected:
            return snapshot.connectionState == .reconnecting ? "正在重新連線" : "未連線"
        case .zeroAgents:
            return "沒有 Agent"
        case .normal:
            var parts = summary.items.filter(\.isVisible).map { "\(name(of: $0.state)) \($0.count) 個" }
            if summary.hasHiddenStates {
                let showsDone = summary.items.contains { $0.state == .done }
                parts.append(showsDone ? "另有錯誤或未知的 Agent" : "另有已完成、錯誤或未知的 Agent")
            }
            return parts.joined(separator: "，")
        }
    }

    private func name(of state: NormalizedState) -> String {
        switch state {
        case .working: "工作中"
        case .needsApproval: "等待核准"
        case .idle: "閒置"
        case .done: "已完成"
        case .error: "錯誤"
        case .unknown: "未知"
        }
    }
}
