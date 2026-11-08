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

        // 預設連 Herdr 的本機 socket。Herdr 沒在執行時畫面顯示斷線，不改用示範資料。
        // 設定環境變數 IDLEVILLAGER_DEMO=1 才以 Fake Adapter 的示範快照啟動（來源顯示「示範資料」，focus 回傳示範模式失敗）。
        let adapter: any HerdrAdapter
        if ProcessInfo.processInfo.environment["IDLEVILLAGER_DEMO"] == "1" {
            adapter = FakeHerdrAdapter(snapshot: .demo)
        } else {
            adapter = HerdrSocketAdapter(activator: AppKitTerminalActivator())
        }
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
            // 在 View 內讀 store.snapshot 才會被 Observation 追蹤；在 Scene 層讀取時，Popover 開著期間不會重繪。
            LiveSessionPopover(store: store)
                .environment(focusCoordinator)
                .environment(settings)
        } label: {
            LiveMenuBarLabel(store: store, settings: settings)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings)
        }
    }
}

/// 觀察 Session Store 並把最新快照交給 Popover 內容。
///
/// 必須在 View 的 body 內讀取 `store.snapshot`，SwiftUI 才會在快照變動時重繪已開啟的 Popover；
/// 若在 `App.body` 的 Scene 層讀取，Popover 開著時清單會停在開啟當下的資料，點擊舊列會得到「目標已不存在」。
struct LiveSessionPopover: View {
    let store: SessionStore

    var body: some View {
        SessionPopoverView(snapshot: store.snapshot)
    }
}

/// 觀察 Session Store 並把最新快照交給選單列 label，理由同 `LiveSessionPopover`。
struct LiveMenuBarLabel: View {
    let store: SessionStore
    let settings: AppSettings

    var body: some View {
        MenuBarLabel(snapshot: store.snapshot, settings: settings)
            .approvalAlert(needsApprovalCount: store.snapshot.counts.needsApproval, settings: settings)
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
                } else if summary.mode == .normal {
                    MenuBarCountsLabel(summary: summary)
                } else {
                    // 零 Agent 模式維持文字。
                    Text(MenuBarSummaryFormatter.text(for: summary))
                }
            }
            .accessibilityLabel(accessibilityText(for: summary))
        }
    }

    private func accessibilityText(for summary: MenuBarSummary) -> String {
        switch summary.mode {
        case .disconnected:
            return snapshot.connectionState == .reconnecting ? "重新連線中" : "未連線"
        case .zeroAgents:
            return "沒有 Agent"
        case .normal:
            var parts = summary.items.filter(\.isVisible).map { "\($0.state.shortText) \($0.count) 個" }
            if summary.hasHiddenStates {
                let showsDone = summary.items.contains { $0.state == .done }
                parts.append(showsDone ? "另有錯誤或訊號不足的 Agent" : "另有完成、錯誤或訊號不足的 Agent")
            }
            return parts.joined(separator: "，")
        }
    }
}

/// 數量模式的選單列內容：最左一個 16 pt IdleVillager 選單列標誌（`VillagerSymbolShape`），後面依序是各類別的 SF Symbol 與數量，有隱藏狀態時尾端加小標記。
///
/// 類別、數量與是否顯示完全取自 `MenuBarSummary.items`，這裡不自行計數。
/// 與少量角色模式相同，`MenuBarExtra` 的 label 只可靠地呈現單一圖片或文字，所以整排先以 `MenuBarImageRendering`
/// 畫成 template 圖片，讓系統依選單列外觀自動套用明暗色。無障礙文字由外層 `MenuBarLabel` 提供。
///
/// 低干擾提醒進行中時（`menuBarAlertEmphasis` 為 `.emphasized`），等核准類別加上與角色模式相同的圓角底色並改粗體。
struct MenuBarCountsLabel: View {
    let summary: MenuBarSummary

    @Environment(\.displayScale) private var displayScale
    @Environment(\.menuBarAlertEmphasis) private var emphasis

    var body: some View {
        Image(nsImage: renderedImage)
    }

    private var renderedImage: NSImage {
        MenuBarImageRendering.image(of: MenuBarCountsRow(summary: summary, emphasis: emphasis), scale: displayScale)
    }
}

/// 實際排版的一排選單列標誌、狀態圖示與數量，只供 `ImageRenderer` 繪製。
private struct MenuBarCountsRow: View {
    let summary: MenuBarSummary
    let emphasis: MenuBarAlertEmphasis

    var body: some View {
        HStack(spacing: 2) {
            // IdleVillager 自有標誌（斗笠村民半身），只是產品識別，不代表任何 Session 的狀態。
            // 以前這裡放 16 pt 的 Generic 村民，但 16 pt 只畫本體，看起來是一顆實心圓，容易被誤認為狀態標記（Issue #40）。
            VillagerSymbolShape()
                .fill(.primary)
                .frame(width: IdleVillagerMark.menuBarSize, height: IdleVillagerMark.menuBarSize)
                .padding(.trailing, IdleVillagerMark.menuBarTrailingGap)
            ForEach(summary.items.filter(\.isVisible), id: \.state) { item in
                let highlighted = emphasis == .emphasized && item.state == .needsApproval
                HStack(spacing: 2) {
                    Image(systemName: item.state.symbolName)
                        .font(.system(size: 11, weight: highlighted ? .bold : .semibold))
                    Text("\(item.count)")
                        .font(.system(size: 13, weight: highlighted ? .bold : .regular).monospacedDigit())
                }
                .menuBarEmphasisBackground(highlighted)
            }
            if summary.hasHiddenStates {
                Text(MenuBarSummaryFormatter.hiddenStatesMarker)
                    .font(.system(size: 13))
            }
        }
        .frame(height: 18)
    }
}
