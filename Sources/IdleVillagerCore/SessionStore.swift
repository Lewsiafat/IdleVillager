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

    public init(session: AgentSession, normalizedState: NormalizedState) {
        self.session = session
        self.normalizedState = normalizedState
    }

    public var id: AgentSessionID { session.agentSessionID }
}

/// Session Store 對外的可觀察快照。
public struct StoreSnapshot: Hashable, Sendable {
    public var connectionState: ConnectionState
    public var lastUpdatedAt: Date?
    public var sessions: [StoreSession]
    public var counts: StateCounts

    public init(
        connectionState: ConnectionState,
        lastUpdatedAt: Date?,
        sessions: [StoreSession],
        counts: StateCounts
    ) {
        self.connectionState = connectionState
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

    /// - Parameters:
    ///   - adapter: 資料來源。
    ///   - now: 時鐘，用於 `lastUpdatedAt`；測試可注入固定時間。
    public init(adapter: any HerdrAdapter, now: @escaping @Sendable () -> Date = { Date() }) {
        self.adapter = adapter
        self.now = now
        self.snapshot = StoreSnapshot(
            connectionState: .disconnected,
            lastUpdatedAt: nil,
            sessions: [],
            counts: StateCounts()
        )
    }

    /// 讀取 Adapter 快照，然後持續處理事件，直到事件串流結束或呼叫端的 Task 被取消才返回。
    ///
    /// App 端在啟動時以 `Task { await store.start() }` 呼叫；測試可先讓 Fake Adapter `finish()`，`start()` 會在處理完已推送的事件後返回。
    public func start() async {
        do {
            let source = try await adapter.snapshot()
            replaceSessions(with: source.sessions)
            snapshot.connectionState = .connected
            snapshot.lastUpdatedAt = now()
        } catch {
            snapshot.connectionState = .disconnected
        }

        for await event in adapter.events {
            handle(event)
        }
    }

    private func handle(_ event: AdapterEvent) {
        switch event {
        case .sessionAdded(let session):
            var sessions = snapshot.sessions.map(\.session)
            sessions.removeAll { $0.agentSessionID == session.agentSessionID }
            sessions.append(session)
            replaceSessions(with: sessions)
            snapshot.lastUpdatedAt = now()
        case .sessionRemoved(let id):
            replaceSessions(with: snapshot.sessions.map(\.session).filter { $0.agentSessionID != id })
            snapshot.lastUpdatedAt = now()
        case .sessionStateChanged(let id, let rawState, let stateSource, let updatedAt):
            let sessions = snapshot.sessions.map { entry -> AgentSession in
                var session = entry.session
                if session.agentSessionID == id {
                    session.rawState = rawState
                    session.stateSource = stateSource
                    session.updatedAt = updatedAt
                }
                return session
            }
            replaceSessions(with: sessions)
            snapshot.lastUpdatedAt = now()
        case .connectionChanged(let state):
            // lastUpdatedAt 代表最後一次成功取得資料的時間，連線狀態變更不更新它。
            snapshot.connectionState = state
        }
    }

    private func replaceSessions(with sessions: [AgentSession]) {
        // 正規化規則尚未實作，所有 Session 先視為 unknown。
        let entries = sessions.map { StoreSession(session: $0, normalizedState: .unknown) }
        var counts = StateCounts()
        for entry in entries { counts[entry.normalizedState] += 1 }
        snapshot.sessions = entries
        snapshot.counts = counts
    }
}
