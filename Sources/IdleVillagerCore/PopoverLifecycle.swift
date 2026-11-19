import Foundation
import Observation

/// Popover 生命週期：Popover 開著的期間要知道與要做的事，都由這裡負責。
///
/// 負責四件事：
/// - 目前是否可見（`isVisible`）。還沒收到任何回報時視為不可見，角色因此不會在看不見的視窗裡播放動畫。
/// - 從可見變成不可見時的清理：清除切換失敗提示，並清除 hover 的列，下次打開時不會殘留。
/// - 點擊一列之後的流程：呼叫持有的 `FocusCoordinator`；成功就要求關閉 Popover，失敗就保持開啟並公開失敗提示。
/// - Tab 收合狀態：只存在記憶體中，重啟後不保留。
///
/// App 層只負責回報「可見或不可見」、hover 與「點擊了哪一列」，並依這裡的狀態繪製。
/// 只用穩定的 `AgentSessionID`、`PaneID` 與 `TabID`，不使用清單索引。
@MainActor
@Observable
public final class PopoverLifecycle {
    /// 點擊一列之後，Popover 該怎麼做。
    public enum RowClickResponse: Hashable, Sendable {
        /// Focus 成功，關閉 Popover。
        case closePopover
        /// Focus 失敗，保持開啟，原因由 `focusFailure` 顯示。
        case keepOpen
    }

    /// Popover 目前是否顯示在畫面上。還沒收到任何回報時為 false。
    public private(set) var isVisible = false
    public private(set) var collapsedTabs: Set<TabID> = []
    /// 滑鼠目前指著的列；Popover 不可見時一律為 nil。
    public private(set) var hoveredRow: AgentSessionID?

    @ObservationIgnored private let focusCoordinator: FocusCoordinator

    public init(focusCoordinator: FocusCoordinator) {
        self.focusCoordinator = focusCoordinator
    }

    /// 顯示在 Popover 頂部的切換失敗提示。失敗提示由 `FocusCoordinator` 擁有，這裡只轉交。
    public var focusFailure: FocusFailure? {
        focusCoordinator.lastFailure
    }

    /// App 回報 Popover 的視窗是否可見。從可見變成不可見時，清除失敗提示與 hover。
    public func visibilityChanged(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        if !visible {
            focusCoordinator.clearFailure()
            hoveredRow = nil
        }
    }

    /// 使用者點擊一列：交給 `FocusCoordinator`，成功就要求關閉 Popover，失敗就保持開啟。
    public func rowClicked(sessionID: AgentSessionID, paneID: PaneID) async -> RowClickResponse {
        switch await focusCoordinator.focus(sessionID: sessionID, paneID: paneID) {
        case .success: .closePopover
        case .failure: .keepOpen
        }
    }

    /// 使用者按下失敗提示的關閉按鈕。
    public func dismissFocusFailure() {
        focusCoordinator.clearFailure()
    }

    /// App 回報某一列的 hover 開始或結束。不可見時的回報不採用；結束只清除同一列，避免換列時舊列的結束蓋掉新列。
    public func hoverChanged(sessionID: AgentSessionID, isHovered: Bool) {
        if isHovered {
            guard isVisible else { return }
            hoveredRow = sessionID
        } else if hoveredRow == sessionID {
            hoveredRow = nil
        }
    }

    public func isHovered(_ sessionID: AgentSessionID) -> Bool {
        hoveredRow == sessionID
    }

    public func isCollapsed(_ tab: TabID) -> Bool {
        collapsedTabs.contains(tab)
    }

    public func toggleCollapsed(_ tab: TabID) {
        if collapsedTabs.contains(tab) {
            collapsedTabs.remove(tab)
        } else {
            collapsedTabs.insert(tab)
        }
    }
}
