import Foundation

/// 與 Herdr 的連線狀態。
public enum ConnectionState: Hashable, Sendable {
    case connected
    case disconnected
    case reconnecting
}

/// Adapter 以非同步串流送出的變更事件。
public enum AdapterEvent: Hashable, Sendable {
    case sessionAdded(AgentSession)
    case sessionRemoved(AgentSessionID)
    case sessionStateChanged(AgentSessionID, rawState: String, stateSource: StateSource, updatedAt: Date)
    case connectionChanged(ConnectionState)
}

/// Focus 失敗的明確原因。
public enum FocusFailureReason: Hashable, Sendable {
    /// 目標 Session 或 Pane 已不存在。
    case targetNotFound
    /// Herdr 不支援聚焦到此目標。
    case unsupported
    /// 與 Herdr 斷線。
    case disconnected
    /// 作業系統未能把 Herdr 視窗帶到前景。
    case windowNotBroughtToFront
}

/// Focus 請求的結果。
public enum FocusResult: Hashable, Sendable {
    case success
    case failure(FocusFailureReason)
}

/// 整個系統唯一的外部邊界，也是唯一的測試 seam。
///
/// 真實的 Herdr 實作必須先在使用者環境驗證 API；此 protocol 不代表 Herdr API 已確認。
public protocol HerdrAdapter: Sendable {
    /// 取得目前完整的 Workspace / Tab / Pane / Agent Session 階層快照。
    func snapshot() async throws -> SessionSnapshot

    /// 變更事件串流。串流結束代表 Adapter 不再送出事件。
    var events: AsyncStream<AdapterEvent> { get }

    /// 聚焦指定 Pane，回傳成功或帶原因的失敗。
    func focus(sessionID: AgentSessionID, paneID: PaneID) async -> FocusResult
}
