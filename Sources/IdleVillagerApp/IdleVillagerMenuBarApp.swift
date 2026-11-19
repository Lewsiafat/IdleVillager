import AppKit
import SwiftUI
import IdleVillagerCore

@main
struct IdleVillagerMenuBarApp: App {
    @State private var store: SessionStore
    @State private var popoverLifecycle: PopoverLifecycle
    @State private var settings: AppSettings

    init() {
        // 先決定介面語言，之後建立的模型與畫面文字（含示範資料與來源名稱）才會用對語言。
        // 語言取自使用者在設定畫面的選擇；從未選過時是英文，不跟隨 macOS 的偏好語言。
        let settings = AppSettings(store: UserDefaultsSettingsStore())
        L10n.use(settings.language)
        _settings = State(initialValue: settings)

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
        _popoverLifecycle = State(initialValue: PopoverLifecycle(
            focusCoordinator: FocusCoordinator(store: store, adapter: adapter)
        ))
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
                .environment(popoverLifecycle)
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
///
/// 介面語言改變時以 `.id` 重建整個 Popover：`L10n.text` 不受 SwiftUI 追蹤，不重建的話已畫出的文字會停在舊語言。
struct LiveSessionPopover: View {
    let store: SessionStore
    @Environment(AppSettings.self) private var settings

    var body: some View {
        SessionPopoverView(snapshot: store.snapshot)
            .id(settings.language)
    }
}

/// 觀察 Session Store 並把最新快照交給選單列 label，理由同 `LiveSessionPopover`。
struct LiveMenuBarLabel: View {
    let store: SessionStore
    let settings: AppSettings

    var body: some View {
        // 語言改變時重建，讓無障礙文字換成新語言，理由同 `LiveSessionPopover`。
        MenuBarLabel(snapshot: store.snapshot, settings: settings)
            .approvalAlert(needsApprovalCount: store.snapshot.counts.needsApproval, settings: settings)
            .id(settings.language)
    }
}

/// 選單列 label，要畫什麼完全由 `MenuBarPresentation` 決定；這裡只依它排版，不自行推論狀態、組無障礙文字或判斷強調。
/// 因觀察 `AppSettings`，設定改動時即時重繪。
///
/// 提醒強調程度取自 `MenuBarAlertModifier` 設定的 `menuBarAlertEmphasis` 環境值；設定視窗的選單列預覽沒有套用提醒，維持不強調。
struct MenuBarLabel: View {
    let snapshot: StoreSnapshot
    let settings: AppSettings

    @Environment(\.menuBarAlertEmphasis) private var emphasis

    var body: some View {
        let presentation = MenuBarPresentation(
            snapshot: snapshot,
            settings: settings,
            emphasis: emphasis,
            isBrandAssetAvailable: BrandAssetCatalog.isAvailable
        )
        Group {
            switch presentation.content {
            case .disconnected(let symbolName):
                Image(systemName: symbolName)
            case .zeroAgents(let text):
                Text(text)
            case .counts(let cells, let hiddenStatesMarker):
                MenuBarCountsLabel(
                    cells: cells,
                    hiddenStatesMarker: hiddenStatesMarker,
                    usesTemplateImage: presentation.usesTemplateImage
                )
            case .characters(let cells):
                MenuBarCharactersLabel(cells: cells, usesTemplateImage: presentation.usesTemplateImage)
            }
        }
        .accessibilityLabel(presentation.accessibilityText)
    }
}

/// 數量模式的選單列內容：最左一個 16 pt IdleVillager 選單列標誌（`VillagerSymbolShape`），後面依序是各類別的 SF Symbol 與數量，有隱藏狀態時尾端加小標記。
///
/// 類別、數量、是否強調與小標記完全取自 `MenuBarPresentation`，這裡不自行計數或判斷。
/// 與少量角色模式相同，`MenuBarExtra` 的 label 只可靠地呈現單一圖片或文字，所以整排先以 `MenuBarImageRendering`
/// 畫成 template 圖片，讓系統依選單列外觀自動套用明暗色。無障礙文字由外層 `MenuBarLabel` 提供。
///
/// 低干擾提醒進行中時，強調的那一格（等核准）加上與角色模式相同的圓角底色並改粗體。
struct MenuBarCountsLabel: View {
    let cells: [MenuBarPresentation.CountCell]
    let hiddenStatesMarker: String?
    let usesTemplateImage: Bool

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Image(nsImage: renderedImage)
    }

    private var renderedImage: NSImage {
        MenuBarImageRendering.image(
            of: MenuBarCountsRow(cells: cells, hiddenStatesMarker: hiddenStatesMarker),
            scale: displayScale,
            isTemplate: usesTemplateImage
        )
    }
}

/// 實際排版的一排選單列標誌、狀態圖示與數量，只供 `ImageRenderer` 繪製。
private struct MenuBarCountsRow: View {
    let cells: [MenuBarPresentation.CountCell]
    let hiddenStatesMarker: String?

    var body: some View {
        HStack(spacing: 2) {
            // IdleVillager 自有標誌（斗笠村民半身），只是產品識別，不代表任何 Session 的狀態。
            // 以前這裡放 16 pt 的 Generic 村民，但 16 pt 只畫本體，看起來是一顆實心圓，容易被誤認為狀態標記（Issue #40）。
            VillagerSymbolShape()
                .fill(.primary)
                .frame(width: IdleVillagerMark.menuBarSize, height: IdleVillagerMark.menuBarSize)
                .padding(.trailing, IdleVillagerMark.menuBarTrailingGap)
            ForEach(cells) { cell in
                HStack(spacing: 2) {
                    Image(systemName: cell.symbolName)
                        .font(.system(size: 11, weight: cell.isHighlighted ? .bold : .semibold))
                    Text("\(cell.count)")
                        .font(.system(size: 13, weight: cell.isHighlighted ? .bold : .regular).monospacedDigit())
                }
                .menuBarEmphasisBackground(cell.isHighlighted)
            }
            if let hiddenStatesMarker {
                Text(hiddenStatesMarker)
                    .font(.system(size: 13))
            }
        }
        .frame(height: 18)
    }
}
