import Foundation
import Observation

/// 六種正規化狀態。
public enum NormalizedState: String, CaseIterable, Hashable, Sendable {
    case working
    case needsApproval
    case done
    case idle
    case error
    case unknown
}

/// 六種正規化狀態的計數。
public struct StateCounts: Hashable, Sendable {
    public var working = 0
    public var needsApproval = 0
    public var done = 0
    public var idle = 0
    public var error = 0
    public var unknown = 0

    public init() {}

    public var total: Int { working + needsApproval + done + idle + error + unknown }

    /// 取得指定狀態的計數。
    public subscript(state: NormalizedState) -> Int {
        get {
            switch state {
            case .working: working
            case .needsApproval: needsApproval
            case .done: done
            case .idle: idle
            case .error: error
            case .unknown: unknown
            }
        }
        set {
            switch state {
            case .working: working = newValue
            case .needsApproval: needsApproval = newValue
            case .done: done = newValue
            case .idle: idle = newValue
            case .error: error = newValue
            case .unknown: unknown = newValue
            }
        }
    }
}

/// Store 內的一筆 Session：Adapter 原始資料加上正規化狀態。
public struct StoreSession: Hashable, Sendable, Identifiable {
    public var session: AgentSession
    public var normalizedState: NormalizedState
    /// 訊號互相衝突時的非敏感描述（只含正規化狀態名稱），供清單顯示；沒有衝突時為 nil。
    public var conflictNote: String?
    /// 資料是否已不新鮮：自 `session.updatedAt` 與上次成功快照時間兩者較晚者起超過 Store 的 `staleThreshold`，
    /// 或與 Herdr 斷線、重連中時為 true。
    public var isStale: Bool

    public init(
        session: AgentSession,
        normalizedState: NormalizedState,
        conflictNote: String? = nil,
        isStale: Bool = false
    ) {
        self.session = session
        self.normalizedState = normalizedState
        self.conflictNote = conflictNote
        self.isStale = isStale
    }

    public var id: AgentSessionID { session.agentSessionID }
}

/// Session Store 對外的可觀察快照。
public struct StoreSnapshot: Hashable, Sendable {
    public var connectionState: ConnectionState
    /// Adapter 的來源描述。Footer 直接顯示它，清單模型不另寫來源名稱。
    public var sourceDescription: String
    public var lastUpdatedAt: Date?
    public var sessions: [StoreSession]
    public var counts: StateCounts

    public init(
        connectionState: ConnectionState,
        sourceDescription: String,
        lastUpdatedAt: Date?,
        sessions: [StoreSession],
        counts: StateCounts
    ) {
        self.connectionState = connectionState
        self.sourceDescription = sourceDescription
        self.lastUpdatedAt = lastUpdatedAt
        self.sessions = sessions
        self.counts = counts
    }
}

/// 以 agentSessionID 為主鍵維護即時 Session 清單，對外提供可觀察的 `snapshot`。
@MainActor
@Observable
public final class SessionStore {
    public private(set) var snapshot: StoreSnapshot

    @ObservationIgnored private let adapter: any HerdrAdapter
    @ObservationIgnored private let now: @Sendable () -> Date
    /// 過期門檻（秒）。
    public let staleThreshold: TimeInterval
    /// 上次成功讀取 Adapter 快照的時間；過期判定的基準之一。
    @ObservationIgnored private var lastSnapshotAt: Date?

    /// 預設過期門檻：60 秒。
    public nonisolated static let defaultStaleThreshold: TimeInterval = 60

    /// - Parameters:
    ///   - adapter: 資料來源。
    ///   - now: 時鐘，用於 `lastUpdatedAt` 與過期判定；測試可注入固定時間。
    ///   - staleThreshold: 超過這個秒數沒有更新的 Session 標記為過期。
    public init(
        adapter: any HerdrAdapter,
        now: @escaping @Sendable () -> Date = { Date() },
        staleThreshold: TimeInterval = SessionStore.defaultStaleThreshold
    ) {
        self.adapter = adapter
        self.now = now
        self.staleThreshold = staleThreshold
        self.snapshot = StoreSnapshot(
            connectionState: .disconnected,
            sourceDescription: adapter.sourceDescription,
            lastUpdatedAt: nil,
            sessions: [],
            counts: StateCounts()
        )
    }

    /// 讀取 Adapter 快照，然後持續處理事件，直到事件串流結束或呼叫端的 Task 被取消才返回。
    ///
    /// Adapter 回報重新連上（`connectionChanged(.connected)`）時，Store 會重新讀取一次完整快照，
    /// 以同步斷線期間錯過的變更；讀取成功才轉為 connected，失敗則維持 disconnected 並保留上次的清單。
    ///
    /// App 端在啟動時以 `Task { await store.start() }` 呼叫；測試可先讓 Fake Adapter `finish()`，`start()` 會在處理完已推送的事件後返回。
    public func start() async {
        await loadSnapshot()

        for await event in adapter.events {
            if case .connectionChanged(.connected) = event {
                await loadSnapshot()
            } else {
                handle(event)
            }
        }
    }

    /// 讀取 Adapter 的完整快照並取代目前清單；讀取失敗時標記為斷線，保留上次的清單與最後成功更新時間。
    private func loadSnapshot() async {
        do {
            let source = try await adapter.snapshot()
            let time = now()
            lastSnapshotAt = time
            snapshot.connectionState = .connected
            snapshot.lastUpdatedAt = time
            replaceSessions(with: source.sessions, at: time)
        } catch {
            snapshot.connectionState = .disconnected
            refreshStaleness(at: now())
        }
    }

    /// 依目前時鐘重新評估每個 Session 的 `isStale`。
    ///
    /// 每次處理事件時 Store 會自動重算；沒有事件時由 App 以 Timer 定期呼叫，讓久未更新的 Session 轉為過期。
    public func refreshStaleness() {
        refreshStaleness(at: now())
    }

    private func handle(_ event: AdapterEvent) {
        let time = now()
        switch event {
        case .sessionAdded(let session):
            var sessions = snapshot.sessions.map(\.session)
            sessions.removeAll { $0.agentSessionID == session.agentSessionID }
            sessions.append(session)
            snapshot.lastUpdatedAt = time
            replaceSessions(with: sessions, at: time)
        case .sessionRemoved(let id):
            snapshot.lastUpdatedAt = time
            replaceSessions(with: snapshot.sessions.map(\.session).filter { $0.agentSessionID != id }, at: time)
        case .sessionStateChanged(let id, let rawState, let stateSource, let updatedAt, let waitingReason):
            let sessions = snapshot.sessions.map { entry -> AgentSession in
                var session = entry.session
                if session.agentSessionID == id {
                    session.rawState = rawState
                    session.stateSource = stateSource
                    session.updatedAt = updatedAt
                    // 等待原因屬於狀態的一部分，隨狀態一起取代，避免舊原因留在新狀態上。
                    session.waitingReason = waitingReason
                }
                return session
            }
            snapshot.lastUpdatedAt = time
            replaceSessions(with: sessions, at: time)
        case .connectionChanged(let state):
            // 重新連上由 start() 改走 loadSnapshot()；這裡只處理斷線與重連中。
            // lastUpdatedAt 代表最後一次成功取得資料的時間，連線狀態變更不更新它。
            snapshot.connectionState = state
            refreshStaleness(at: time)
        }
    }

    private func refreshStaleness(at time: Date) {
        snapshot.sessions = snapshot.sessions.map { entry in
            var entry = entry
            entry.isStale = isStale(entry.session, at: time)
            return entry
        }
    }

    /// 斷線或重連中一律過期；否則以 `updatedAt` 與上次成功快照時間兩者較晚者為基準，超過門檻才算過期。
    private func isStale(_ session: AgentSession, at time: Date) -> Bool {
        guard snapshot.connectionState == .connected else { return true }
        let reference = max(session.updatedAt, lastSnapshotAt ?? session.updatedAt)
        return time.timeIntervalSince(reference) > staleThreshold
    }

    private func replaceSessions(with sessions: [AgentSession], at time: Date) {
        let entries = sessions.map { session in
            let result = StateNormalizer.normalize(session)
            return StoreSession(
                session: session,
                normalizedState: result.state,
                conflictNote: result.conflictNote,
                isStale: isStale(session, at: time)
            )
        }
        var counts = StateCounts()
        for entry in entries { counts[entry.normalizedState] += 1 }
        snapshot.sessions = entries
        snapshot.counts = counts
    }
}
