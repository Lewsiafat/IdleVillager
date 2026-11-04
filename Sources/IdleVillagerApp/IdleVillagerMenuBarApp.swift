import AppKit
import SwiftUI
import IdleVillagerCore

@main
struct IdleVillagerMenuBarApp: App {
    @State private var store: SessionStore

    init() {
        // 以 Swift Package 執行檔啟動時沒有 Info.plist 的 LSUIElement，改用程式設定成只出現在選單列。
        NSApplication.shared.setActivationPolicy(.accessory)

        // 真實 Herdr Adapter 尚未驗證，先以 Fake Adapter 的空快照啟動。
        let store = SessionStore(adapter: FakeHerdrAdapter(snapshot: .empty))
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

/// 選單列文字。本票只呈現零狀態與斷線，完整摘要模型由後續票實作。
struct MenuBarLabel: View {
    let snapshot: StoreSnapshot

    var body: some View {
        switch snapshot.connectionState {
        case .connected:
            Text("\(snapshot.counts.total) 個 Agent")
        case .disconnected, .reconnecting:
            Image(systemName: "bolt.horizontal.circle")
                .accessibilityLabel("Herdr 未連線")
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
