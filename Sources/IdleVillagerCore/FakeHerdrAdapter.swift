import Foundation

/// 記憶體內的 Herdr Adapter，供測試與 UI 預覽共用。
public actor FakeHerdrAdapter: HerdrAdapter {
    /// 一次 focus 請求的紀錄。
    public struct FocusRequest: Hashable, Sendable {
        public let sessionID: AgentSessionID
        public let paneID: PaneID

        public init(sessionID: AgentSessionID, paneID: PaneID) {
            self.sessionID = sessionID
            self.paneID = paneID
        }
    }

    public nonisolated let events: AsyncStream<AdapterEvent>
    private nonisolated let continuation: AsyncStream<AdapterEvent>.Continuation
    /// 底部資訊區的來源名稱。預設是示範資料，不是已驗證的 Herdr 連線。
    public nonisolated let sourceDescription: String

    private var currentSnapshot: SessionSnapshot
    private var snapshotError: (any Error & Sendable)?
    private var focusResult: FocusResult
    public private(set) var focusRequests: [FocusRequest] = []

    /// - Parameters:
    ///   - snapshot: `snapshot()` 回傳的快照。
    ///   - focusResult: `focus` 的回傳值。預設為示範模式失敗，避免把假成功當成已切回真實 Session。
    ///     測試要模擬成功或其他失敗時，請明確傳入對應的 `FocusResult`。
    ///   - sourceDescription: 底部資訊區的來源名稱。預設「示範資料」。
    public init(
        snapshot: SessionSnapshot = .empty,
        focusResult: FocusResult = .failure(.demoMode),
        sourceDescription: String = SourceDescription.demo
    ) {
        self.currentSnapshot = snapshot
        self.focusResult = focusResult
        self.sourceDescription = sourceDescription
        (events, continuation) = AsyncStream.makeStream(of: AdapterEvent.self)
    }

    public func snapshot() async throws -> SessionSnapshot {
        if let snapshotError { throw snapshotError }
        return currentSnapshot
    }

    public func focus(sessionID: AgentSessionID, paneID: PaneID) async -> FocusResult {
        focusRequests.append(FocusRequest(sessionID: sessionID, paneID: paneID))
        return focusResult
    }

    /// 設定下一次 `snapshot()` 回傳的快照。
    public func setSnapshot(_ snapshot: SessionSnapshot) {
        currentSnapshot = snapshot
    }

    /// 設定 `snapshot()` 要丟出的錯誤；傳入 nil 恢復正常回傳。
    public func setSnapshotError(_ error: (any Error & Sendable)?) {
        snapshotError = error
    }

    /// 設定之後所有 focus 請求的回傳結果。
    public func setFocusResult(_ result: FocusResult) {
        focusResult = result
    }

    /// 依序推送一個事件到 `events`。
    public nonisolated func send(_ event: AdapterEvent) {
        continuation.yield(event)
    }

    /// 結束事件串流。訂閱端的 `for await` 會在處理完已推送的事件後結束。
    public nonisolated func finish() {
        continuation.finish()
    }
}
