import Foundation

/// 清單排序鍵：排序一個項目所需的三個事實。Popover 的列、Tab、Workspace 群組與選單列的角色都用它比較，
/// 排序規則只寫在 `ListOrderKey.precedes(_:_:by:)` 一處。
///
/// - `state`：列與角色是自己的正規化狀態，群組是內含的最高優先度（`topState`）。
/// - `name`：列與角色是 `paneLabel`，群組是 Tab 或 Workspace 名稱。
/// - `id`：穩定 ID 的字串，作為最後的決勝，確保順序穩定。
public struct ListOrderKey: Hashable, Sendable {
    public var state: NormalizedState
    public var name: String
    public var id: String

    public init(state: NormalizedState, name: String, id: String) {
        self.state = state
        self.name = name
        self.id = id
    }

    /// 依排序規則比較兩個鍵，`lhs` 應排在 `rhs` 之前時為 true。
    ///
    /// - `priority`：先比清單優先度，再依名稱（數字以數值比較，Pane 2 在 Pane 10 之前），再依 ID。
    /// - `workspaceName`：依名稱（數字以數值比較），再依 ID，不看狀態。
    /// - `fixed`：只依 ID 的字串順序。
    public static func precedes(_ lhs: ListOrderKey, _ rhs: ListOrderKey, by sortRule: SortRule = .priority) -> Bool {
        if sortRule == .priority, lhs.state.priorityRank != rhs.state.priorityRank {
            return lhs.state.priorityRank < rhs.state.priorityRank
        }
        if sortRule != .fixed {
            switch lhs.name.compare(rhs.name, options: .numeric) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: break
            }
        }
        return lhs.id < rhs.id
    }
}

extension StoreSession {
    /// 這筆 Session 的清單排序鍵：正規化狀態、paneLabel 與 agentSessionID。
    public var listOrderKey: ListOrderKey {
        ListOrderKey(state: normalizedState, name: session.paneLabel, id: session.agentSessionID.rawValue)
    }
}
