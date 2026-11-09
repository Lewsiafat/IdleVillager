import Foundation
import Observation

/// 一次失敗的 Focus：目標的穩定 ID、原因與給使用者看的文字。
public struct FocusFailure: Hashable, Sendable {
    public let sessionID: AgentSessionID
    public let paneID: PaneID
    public let reason: FocusFailureReason

    public init(sessionID: AgentSessionID, paneID: PaneID, reason: FocusFailureReason) {
        self.sessionID = sessionID
        self.paneID = paneID
        self.reason = reason
    }

    /// 使用者可讀的失敗原因。
    public var message: String {
        switch reason {
        case .targetNotFound: L10n.text(.focusTargetNotFound)
        case .unsupported: L10n.text(.focusUnsupported)
        case .disconnected: L10n.text(.focusDisconnected)
        case .windowNotBroughtToFront: L10n.text(.focusWindowNotBroughtToFront)
        case .demoMode: L10n.text(.focusDemoMode)
        }
    }

    /// Popover 頂部顯示的完整文字。
    ///
    /// 一般失敗加上「無法切回：」前綴。示範模式的訊息本身就是完整失敗說明，不再加前綴，
    /// 避免變成「無法切回：示範模式無法切回」。
    public var bannerText: String {
        switch reason {
        case .demoMode: message
        default: L10n.text(.focusBanner, ["reason": message])
        }
    }
}

/// 一次 Focus 請求的結果。
public enum FocusOutcome: Hashable, Sendable {
    case success
    case failure(FocusFailure)
}

/// 處理使用者點擊一列後的 Focus 流程：先向 Store 確認目標仍存在，再呼叫 Adapter。
///
/// 只用穩定的 `AgentSessionID` 與 `PaneID`，不使用清單索引。最近一次失敗公開在 `lastFailure` 供畫面顯示，成功時清空。
@MainActor
@Observable
public final class FocusCoordinator {
    public private(set) var lastFailure: FocusFailure?

    @ObservationIgnored private let store: SessionStore
    @ObservationIgnored private let adapter: any HerdrAdapter

    public init(store: SessionStore, adapter: any HerdrAdapter) {
        self.store = store
        self.adapter = adapter
    }

    /// 聚焦指定 Pane。Store 中找不到該 Session，或其 Pane 已不相符時，不呼叫 Adapter，直接回傳「目標已不存在」。
    public func focus(sessionID: AgentSessionID, paneID: PaneID) async -> FocusOutcome {
        let exists = store.snapshot.sessions.contains {
            $0.session.agentSessionID == sessionID && $0.session.paneID == paneID
        }
        let outcome: FocusOutcome
        if exists {
            switch await adapter.focus(sessionID: sessionID, paneID: paneID) {
            case .success:
                outcome = .success
            case .failure(let reason):
                outcome = .failure(FocusFailure(sessionID: sessionID, paneID: paneID, reason: reason))
            }
        } else {
            outcome = .failure(FocusFailure(sessionID: sessionID, paneID: paneID, reason: .targetNotFound))
        }

        switch outcome {
        case .success: lastFailure = nil
        case .failure(let failure): lastFailure = failure
        }
        return outcome
    }

    /// 清除目前顯示的失敗訊息，例如使用者關閉提示時。
    public func clearFailure() {
        lastFailure = nil
    }
}
