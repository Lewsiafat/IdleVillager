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

/// Popover 內容，完全由 `SessionListModel` 決定；畫面不自行推論狀態或排序。
struct SessionPopoverView: View {
    let snapshot: StoreSnapshot
    @State private var viewModel = SessionPopoverViewModel()

    static let width: CGFloat = 360
    static let rowHeight: CGFloat = 36

    var body: some View {
        let model = SessionListModel(snapshot: snapshot)
        VStack(alignment: .leading, spacing: 0) {
            header(model)
            Divider()
            content(model)
            Divider()
            footer(model.footer)
        }
        .frame(width: Self.width)
    }

    private func header(_ model: SessionListModel) -> some View {
        HStack {
            Text(model.title)
                .font(.headline)
            Spacer()
            Text("\(model.agentCount) 個 Agent")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func content(_ model: SessionListModel) -> some View {
        if model.workspaces.isEmpty {
            Text(model.footer.connectionState == .connected ? "目前沒有 Agent Session" : "尚未取得 Session 資料")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.workspaces) { workspace in
                        WorkspaceSection(workspace: workspace, viewModel: viewModel)
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 480)
        }
    }

    private func footer(_ footer: SessionListModel.Footer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: footer.connectionState == .connected ? "link" : "exclamationmark.triangle")
                    .accessibilityHidden(true)
                Text("來源：\(footer.sourceName) · \(footer.connectionText)")
                Spacer()
                if let lastUpdatedAt = footer.lastUpdatedAt {
                    Text("更新於 \(lastUpdatedAt.formatted(date: .omitted, time: .standard))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if footer.connectionState != .connected {
                Text("資料可能已過期，以上清單為最後一次成功更新的內容。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("結束 IdleVillager") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .accessibilityAddTraits(.isHeader)

            ForEach(workspace.tabs) { tab in
                TabSection(tab: tab, viewModel: viewModel)
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
                        Text("\(SessionListModel.icon(for: tab.topState)) \(tab.rows.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.leading, 24)
                .padding(.trailing, 12)
                .frame(height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(tab.name)，\(tab.rows.count) 個 Agent")
            .accessibilityValue(collapsed ? "已收合" : "已展開")
            .accessibilityHint("切換收合")

            if !collapsed {
                ForEach(tab.rows) { row in
                    SessionRowView(row: row)
                }
            }
        }
    }
}

/// 一列 Agent Session：狀態圖示、顯示名稱、Pane 識別與狀態文字。點擊行為由後續的 Focus 票實作。
private struct SessionRowView: View {
    let row: SessionListModel.Row
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 8) {
            CharacterView(state: row.state)
            Text(row.icon)
                .font(.body.weight(.bold))
                .foregroundStyle(iconStyle)
                .frame(width: 22, alignment: .center)
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
            Text(row.stateText)
                .font(.callout.weight(contrast == .increased ? .semibold : .regular))
                .foregroundStyle(contrast == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        }
        .padding(.leading, 42)
        .padding(.trailing, 12)
        .frame(height: SessionPopoverView.rowHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// 顏色只是輔助；狀態一定同時有圖示與文字。高對比時一律使用主要前景色。
    private var iconStyle: AnyShapeStyle {
        if contrast == .increased { return AnyShapeStyle(.primary) }
        switch row.state {
        case .working: return AnyShapeStyle(.green)
        case .needsApproval: return AnyShapeStyle(.orange)
        case .done: return AnyShapeStyle(.yellow)
        case .error: return AnyShapeStyle(.red)
        case .idle, .unknown: return AnyShapeStyle(.secondary)
        }
    }

    private var accessibilityText: String {
        var parts = [row.displayName, row.paneLabel, row.stateText]
        if let detail = row.detail { parts.append(detail) }
        return parts.joined(separator: "，")
    }
}
