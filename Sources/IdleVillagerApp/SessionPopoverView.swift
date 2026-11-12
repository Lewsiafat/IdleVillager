import AppKit
import Observation
import SwiftUI
import IdleVillagerCore

/// Popover 的畫面狀態。Tab 收合狀態只存在記憶體中，重啟後不保留。
@MainActor
@Observable
final class SessionPopoverViewModel {
    private(set) var collapsedTabs: Set<TabID> = []

    func isCollapsed(_ tab: TabID) -> Bool {
        collapsedTabs.contains(tab)
    }

    func toggle(_ tab: TabID) {
        if collapsedTabs.contains(tab) {
            collapsedTabs.remove(tab)
        } else {
            collapsedTabs.insert(tab)
        }
    }
}

/// Popover 內容，完全由 `SessionListModel` 決定；畫面不自行推論狀態或排序。排序規則與動畫開關來自環境中的 `AppSettings`。
struct SessionPopoverView: View {
    let snapshot: StoreSnapshot
    @State private var viewModel = SessionPopoverViewModel()
    /// 清單內容量到的實際高度；nil 表示還沒量到（第一次排版前）。
    @State private var listContentHeight: CGFloat?
    /// Popover 目前是否顯示在畫面上。`MenuBarExtra` 關閉時只把視窗藏起來，不會觸發 `onDisappear`，
    /// SwiftUI 也不會停掉 `PhaseAnimator`；不停的話隱藏的視窗每一幀都重做版面配置，CPU 持續約 25%。
    /// 因此改由 `WindowVisibilityObserver` 直接看 AppKit 視窗是否可見。
    @State private var isVisible = false
    @Environment(FocusCoordinator.self) private var focusCoordinator
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    static let width: CGFloat = 400
    /// 列的最小高度；系統字體放大時列可以長高，不截字。
    static let rowHeight: CGFloat = 36
    /// 清單區的最大高度；內容超過就捲動。
    static let maxListHeight: CGFloat = 560

    var body: some View {
        let model = SessionListModel(snapshot: snapshot, settings: settings)
        VStack(alignment: .leading, spacing: 0) {
            header(model)
            Divider()
            focusFailureBanner
            content(model)
            Divider()
            footer(model.footer)
        }
        .frame(width: Self.width)
        // Translucent or opaque background, decided in Core from the setting and system Reduce Transparency.
        .popoverBackground(settings: settings)
        .environment(\.popoverIsVisible, isVisible)
        .background(WindowVisibilityObserver(isVisible: $isVisible))
        // 重新打開 Popover 時不再顯示上一次的失敗訊息。關閉清單不會觸發 onDisappear，所以看視窗是否還可見。
        .onChange(of: isVisible) { wasVisible, nowVisible in
            if wasVisible && !nowVisible { focusCoordinator.clearFailure() }
        }
    }

    /// Focus 失敗時顯示在 Popover 頂部的原因；Popover 保持開啟。
    @ViewBuilder
    private var focusFailureBanner: some View {
        if let failure = focusCoordinator.lastFailure {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text(failure.bannerText)
                    .font(.callout)
                Spacer()
                Button {
                    focusCoordinator.clearFailure()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text(.dismissFocusFailure))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            Divider()
        }
    }

    private func header(_ model: SessionListModel) -> some View {
        HStack(spacing: 8) {
            // 標題旁的 IdleVillager 標誌（斗笠瞇眼臉）只是裝飾，固定靜態。
            SleepyVillagerMarkShape()
                .fill(.primary)
                .frame(width: IdleVillagerMark.popoverSize, height: IdleVillagerMark.popoverSize)
                .accessibilityHidden(true)
            Text(model.title)
                .font(.headline)
            Spacer()
            Text(model.headerStatusText)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func content(_ model: SessionListModel) -> some View {
        if let emptyStateText = model.emptyStateText {
            Text(emptyStateText)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.workspaces) { workspace in
                        WorkspaceSection(workspace: workspace, viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                // ScrollView 自己回報的理想高度會比內容少幾個 pt，最後一列的下緣因此被 footer 的分隔線蓋到。
                // 改成量內容的實際高度，直接指定 ScrollView 的高度；內容超過上限時仍可捲動。
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    listContentHeight = height
                }
            }
            .frame(height: listContentHeight.map { min($0, Self.maxListHeight) })
            .frame(maxHeight: Self.maxListHeight)
        }
    }

    /// `Info.plist` 的 `CFBundleShortVersionString`；`swift run` 執行時沒有，為 nil。
    private static let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

    /// footer 上方是「設定…」與「結束 IdleVillager」兩顆按鈕；文字統一放在下方：來源與連線、版號、更新時間，
    /// 資料過期時再多一行過期提示。
    private func footer(_ footer: SessionListModel.Footer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SettingsEntryButton()
                Spacer()
                Button(L10n.text(.footerQuit)) {
                    NSApplication.shared.terminate(nil)
                }
            }
            // 按鈕用標準尺寸，比 small 稍大、比較好點。
            .controlSize(.regular)

            // 分隔按鈕與下方的狀態文字。
            Divider()

            HStack(spacing: 6) {
                Image(systemName: footer.connectionState == .connected ? "link" : "exclamationmark.triangle")
                    .accessibilityHidden(true)
                Text(L10n.text(.footerSource, ["source": footer.sourceName, "connection": footer.connectionText]))
                Spacer()
                Text(AppVersionLabel.text(shortVersion: Self.shortVersion))
                    .accessibilityLabel(AppVersionLabel.accessibilityText(shortVersion: Self.shortVersion))
                Spacer()
                // 相對時間由 Core 依當下時間產生，定期重繪讓「N 分鐘前」持續正確。
                TimelineView(.periodic(from: .now, by: 10)) { context in
                    Text(footer.lastUpdatedText(now: context.date))
                        .help(footer.lastUpdatedAt.map { $0.formatted(date: .abbreviated, time: .standard) } ?? "")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let staleNotice = footer.staleNotice {
                Text(staleNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        // 按鈕上方留空間，才不會貼著上面的分隔線。
        .padding(.top, 10)
        // 底部多留一點空間，按鈕才不會貼著清單的下緣。
        .padding(.bottom, 10)
        // 半透明背景時墊一層較濃的底色，避免按鈕在亮色桌面上太白、看不清楚。
        .background {
            // 這個 View 自己設定 popoverBackgroundStyle 環境值，讀環境只會拿到上層的預設值，所以直接算。
            if let backing = settings.popoverBackgroundStyle(reduceTransparency: reduceTransparency).footerBackingOpacity {
                Rectangle().fill(.background.opacity(backing))
            }
        }
    }
}

/// 一個 Workspace 群組與其底下的 Tab。
private struct WorkspaceSection: View {
    let workspace: SessionListModel.WorkspaceGroup
    let viewModel: SessionPopoverViewModel
    @Environment(\.popoverBackgroundStyle) private var backgroundStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(workspace.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .accessibilityAddTraits(.isHeader)

            ForEach(workspace.tabs) { tab in
                TabSection(tab: tab, viewModel: viewModel)
            }
        }
        .padding(.vertical, 4)
        // 每個 Workspace 一個圓角底色區塊，Tab 與 Session 列都在區塊內。
        .background {
            let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
            ZStack {
                // On the translucent background, a partly opaque window-background backing keeps rows,
                // characters and state capsules readable over a busy desktop, in light and dark mode.
                if let backing = backgroundStyle.workspaceCardBackingOpacity {
                    shape.fill(.background.opacity(backing))
                }
                shape.fill(.quaternary)
            }
        }
    }
}

/// 一個可收合的 Tab 群組。
private struct TabSection: View {
    let tab: SessionListModel.TabGroup
    let viewModel: SessionPopoverViewModel

    var body: some View {
        let collapsed = viewModel.isCollapsed(tab.id)
        VStack(alignment: .leading, spacing: 0) {
            Button {
                viewModel.toggle(tab.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .frame(width: 12)
                        .accessibilityHidden(true)
                    Text(tab.name)
                        .font(.subheadline)
                        .lineLimit(1)
                    if collapsed {
                        // 收合時仍顯示群組內最高優先度的狀態，避免急件被藏起來。
                        Text("\(tab.topState.icon) \(tab.rows.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.leading, 20)
                .padding(.trailing, 8)
                .frame(minHeight: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.countText(
                one: .tabAccessibilityOne, other: .tabAccessibilityOther, count: tab.rows.count, ["name": tab.name]
            ))
            .accessibilityValue(L10n.text(collapsed ? .tabCollapsed : .tabExpanded))
            .accessibilityHint(L10n.text(.tabToggleHint))

            if !collapsed {
                ForEach(tab.rows) { row in
                    SessionRowView(row: row)
                }
            }
        }
    }
}

/// 一列 Agent Session：狀態圖示、顯示名稱、Pane 識別與狀態文字。整列可點擊，直接以穩定 ID 觸發 Focus，不需確認。
private struct SessionRowView: View {
    let row: SessionListModel.Row
    @Environment(FocusCoordinator.self) private var focusCoordinator
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.popoverIsVisible) private var popoverIsVisible
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            CharacterView(state: row.state, agentKind: row.agentKind,
                          animationsEnabled: settings.animationsEnabled && popoverIsVisible)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(row.displayName) · \(row.paneLabel)")
                    .lineLimit(1)
                if let detail = row.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            StatusCapsule(row: row)
        }
        .padding(.leading, 34)
        .padding(.trailing, 8)
        .frame(minHeight: SessionPopoverView.rowHeight)
        .background {
            // hover 時以淡淡的選取色標示目前指到的列。
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? AnyShapeStyle(.selection.opacity(0.25)) : AnyShapeStyle(.clear))
                .padding(.horizontal, 4)
        }
        .contentShape(Rectangle())
        // 點擊、hover 與手指游標都交給 AppKit 的 view 處理。AppKit 只採用滑鼠底下接收點擊的 view 的游標設定，
        // 用 SwiftUI 的 onTapGesture 時接收點擊的是 SwiftUI 視窗本身，游標會一直被設回箭頭。
        .overlay(ClickableRowArea(onClick: focus, onHoverChange: { isHovered = $0 }))
        .onChange(of: popoverIsVisible) { _, visible in
            // 關閉 Popover 不會觸發 onDisappear，也不會送出 hover 結束；不重設的話，下次打開時這一列還是 hover 的樣子。
            if !visible { isHovered = false }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(L10n.text(.rowFocusHint))
        .accessibilityAction { focus() }
    }

    /// 成功就關閉 Popover；失敗時原因由 Popover 頂部顯示，不關閉。
    private func focus() {
        let sessionID = row.id
        let paneID = row.paneID
        Task {
            if await focusCoordinator.focus(sessionID: sessionID, paneID: paneID) == .success {
                dismiss()
            }
        }
    }

    private var accessibilityText: String {
        var parts = [row.displayName, row.paneLabel, row.stateText]
        if let detail = row.detail { parts.append(detail) }
        return parts.joined(separator: L10n.text(.clauseSeparator))
    }
}

/// 列右側的狀態膠囊：圖示加狀態文字（含「（過期）」等字樣）置於圓角膠囊。
/// 顏色只是輔助，底色依 `NormalizedState.tint`；高對比時改成實線框加主要前景色文字。
private struct StatusCapsule: View {
    let row: SessionListModel.Row
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let highContrast = contrast == .increased
        HStack(spacing: 4) {
            Text(row.icon)
                .fontWeight(.bold)
            Text(row.stateText)
        }
        .font(.caption.weight(highContrast ? .semibold : .medium))
        .lineLimit(1)
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background {
            if highContrast {
                Capsule().strokeBorder(.primary, lineWidth: 1)
            } else {
                Capsule().fill(tintColor.opacity(0.22))
            }
        }
        .fixedSize()
    }

    private var tintColor: Color {
        switch row.state.tint {
        case .green: .green
        case .orange: .orange
        case .yellow: .yellow
        case .red: .red
        case .gray: .gray
        }
    }
}

// 只有 Command Line Tools 時沒有 SwiftUI 的 macro plugin，無法使用 `@Entry`，改用傳統的 EnvironmentKey。
private struct PopoverIsVisibleKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Popover 是否顯示在畫面上，由 `SessionPopoverView` 設定；角色列在 Popover 關閉時停止循環動畫。
    var popoverIsVisible: Bool {
        get { self[PopoverIsVisibleKey.self] }
        set { self[PopoverIsVisibleKey.self] = newValue }
    }
}

/// 回報所在 AppKit 視窗目前是否可見。
///
/// `MenuBarExtra`（`.window` 樣式）關閉時只把視窗藏起來，SwiftUI 的 `onDisappear` 不會觸發（2026-11-12 實測），
/// 因此監聽視窗的遮蔽狀態變化：視窗顯示、隱藏或被完全擋住時，macOS 都會發出 `didChangeOcclusionStateNotification`。
private struct WindowVisibilityObserver: NSViewRepresentable {
    @Binding var isVisible: Bool

    func makeNSView(context: Context) -> ObserverView {
        ObserverView()
    }

    // SwiftUI 建立 View 後一定會接著呼叫這裡，所以只在這裡設定回呼，讓它總是指向最新的 binding。
    func updateNSView(_ nsView: ObserverView, context: Context) {
        nsView.onChange = { visible in
            if isVisible != visible { isVisible = visible }
        }
    }

    final class ObserverView: NSView {
        var onChange: ((Bool) -> Void)?
        private var observer: (any NSObjectProtocol)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            guard let window else {
                report(false)
                return
            }
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.reportCurrent() }
            }
            reportCurrent()
        }

        private func reportCurrent() {
            report(window?.occlusionState.contains(.visible) ?? false)
        }

        private func report(_ visible: Bool) {
            // 不在版面配置或繪製途中直接改 SwiftUI 狀態，留到下一輪執行。
            DispatchQueue.main.async { [weak self] in self?.onChange?(visible) }
        }
    }
}

/// 可點擊的列的滑鼠處理區：顯示手指游標、回報 hover、在滑鼠放開時觸發點擊。
///
/// AppKit 決定游標時，只看滑鼠底下接收點擊的 view，所以這個 view 必須自己接收滑鼠事件，cursor rect 才會生效。
/// 滑鼠移出或視窗隱藏時，游標由系統自動換回，不需要自己 push 或 pop。
/// 這個 view 不出現在輔助使用的元素樹裡；VoiceOver 的操作由 SwiftUI 那一層的 `accessibilityAction` 處理。
private struct ClickableRowArea: NSViewRepresentable {
    let onClick: () -> Void
    let onHoverChange: (Bool) -> Void

    func makeNSView(context: Context) -> AreaView { AreaView() }

    // 每次更新都換成最新的回呼，避免握住舊的 View 狀態。
    func updateNSView(_ nsView: AreaView, context: Context) {
        nsView.onClick = onClick
        nsView.onHoverChange = onHoverChange
    }

    final class AreaView: NSView {
        var onClick: (() -> Void)?
        var onHoverChange: ((Bool) -> Void)?

        override init(frame: NSRect) {
            super.init(frame: frame)
            setAccessibilityElement(false)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        // 清單視窗還不是 key window 時，第一下點擊也要生效。
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .pointingHand)
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for area in trackingAreas { removeTrackingArea(area) }
            addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                           owner: self, userInfo: nil))
        }

        override func mouseEntered(with event: NSEvent) { onHoverChange?(true) }
        override func mouseExited(with event: NSEvent) { onHoverChange?(false) }

        // 覆寫 mouseDown 才會收到 mouseUp；放開時滑鼠仍在範圍內才算點擊，和一般按鈕一樣可以移出取消。
        override func mouseDown(with event: NSEvent) {}

        override func mouseUp(with event: NSEvent) {
            if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
        }
    }
}
