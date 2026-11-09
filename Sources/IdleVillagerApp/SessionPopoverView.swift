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
    @Environment(FocusCoordinator.self) private var focusCoordinator
    @Environment(AppSettings.self) private var settings

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
        // 重新打開 Popover 時不再顯示上一次的失敗訊息。
        .onDisappear { focusCoordinator.clearFailure() }
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

    /// footer 分兩列：第一列是來源、連線與更新時間，第二列是「設定…」、版號與「結束 IdleVillager」。
    private func footer(_ footer: SessionListModel.Footer) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: footer.connectionState == .connected ? "link" : "exclamationmark.triangle")
                    .accessibilityHidden(true)
                Text(L10n.text(.footerSource, ["source": footer.sourceName, "connection": footer.connectionText]))
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

            HStack {
                SettingsEntryButton()
                Spacer()
                Text(AppVersionLabel.text(shortVersion: Self.shortVersion))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(AppVersionLabel.accessibilityText(shortVersion: Self.shortVersion))
                Spacer()
                Button(L10n.text(.footerQuit)) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

/// 一個 Workspace 群組與其底下的 Tab。
private struct WorkspaceSection: View {
    let workspace: SessionListModel.WorkspaceGroup
    let viewModel: SessionPopoverViewModel

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
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
    @State private var isHovered = false
    /// 這一列是否已把手指游標 push 進 `NSCursor` 堆疊。`onHover` 事件可能漏發或重複，
    /// 只依這個旗標在真正轉換時 push 或 pop，確保堆疊不失衡。
    @State private var hasPushedCursor = false

    var body: some View {
        HStack(spacing: 8) {
            CharacterView(state: row.state, agentKind: row.agentKind,
                          animationsEnabled: settings.animationsEnabled)
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
        .onTapGesture { focus() }
        .onHover { hovering in
            isHovered = hovering
            setPointingHandCursor(hovering)
        }
        .onDisappear {
            // 列在 hover 中消失（例如 Popover 關閉或清單更新）時，把游標還原。
            isHovered = false
            setPointingHandCursor(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(L10n.text(.rowFocusHint))
        .accessibilityAction { focus() }
    }

    /// 依需要 push 或 pop 手指游標；狀態沒有改變時不動作。
    private func setPointingHandCursor(_ wantsPointingHand: Bool) {
        guard wantsPointingHand != hasPushedCursor else { return }
        if wantsPointingHand {
            NSCursor.pointingHand.push()
        } else {
            NSCursor.pop()
        }
        hasPushedCursor = wantsPointingHand
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
