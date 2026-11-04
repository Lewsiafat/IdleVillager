import AppKit
import SwiftUI
import IdleVillagerCore

@main
struct IdleVillagerMenuBarApp: App {
    @State private var store: SessionStore

    init() {
        // 以 Swift Package 執行檔啟動時沒有 Info.plist 的 LSUIElement，改用程式設定成只出現在選單列。
        NSApplication.shared.setActivationPolicy(.accessory)

        // 真實 Herdr Adapter 尚未驗證，先以 Fake Adapter 的示範快照啟動。
        let store = SessionStore(adapter: FakeHerdrAdapter(snapshot: .demo))
        _store = State(initialValue: store)
        Task { await store.start() }
    }

    var body: some Scene {
        MenuBarExtra {
            SessionPopoverView(snapshot: store.snapshot)
        } label: {
            MenuBarLabel(snapshot: store.snapshot)
        }
        .menuBarExtraStyle(.window)
    }
}

/// 選單列文字，完全由摘要模型決定；畫面不自行推論狀態。
struct MenuBarLabel: View {
    let snapshot: StoreSnapshot

    var body: some View {
        let summary = MenuBarSummary(snapshot: snapshot)
        Text(MenuBarSummaryFormatter.text(for: summary))
            .accessibilityLabel(accessibilityText(for: summary))
    }

    private func accessibilityText(for summary: MenuBarSummary) -> String {
        switch summary.mode {
        case .disconnected:
            return "Herdr 未連線"
        case .zeroAgents:
            return "沒有 Agent"
        case .normal:
            var parts = summary.items.filter(\.isVisible).map { "\(name(of: $0.state)) \($0.count) 個" }
            if summary.hasHiddenStates { parts.append("另有已完成、錯誤或未知的 Agent") }
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

/// Popover 內容。本票只放標題與 Agent 總數，清單由後續票實作。
struct SessionPopoverView: View {
    let snapshot: StoreSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("IdleVillager")
                    .font(.headline)
                Spacer()
                Text("\(snapshot.counts.total) 個 Agent")
                    .foregroundStyle(.secondary)
            }
            Divider()
            Button("結束 IdleVillager") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 360)
    }
}
