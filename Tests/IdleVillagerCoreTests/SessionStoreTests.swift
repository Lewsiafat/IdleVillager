import Foundation
import Testing
import IdleVillagerCore

private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

private func makeSession(
    id: String = "session-1",
    paneID: String = "pane-1",
    rawState: String = "running"
) -> AgentSession {
    AgentSession(
        workspaceID: WorkspaceID("ws-1"),
        workspaceName: "Main Workspace",
        tabID: TabID("tab-1"),
        tabName: "Backend",
        paneID: PaneID(paneID),
        paneLabel: "Pane 1",
        agentSessionID: AgentSessionID(id),
        agentKind: "claude",
        displayName: "Claude Code",
        rawState: rawState,
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        stateSource: .explicitEvent
    )
}

@MainActor
struct SessionStoreTests {
    @Test func emptySnapshotIsConnectedWithZeroSessionsAndZeroCounts() async {
        let adapter = FakeHerdrAdapter(snapshot: .empty)
        adapter.finish()
        let store = SessionStore(adapter: adapter)

        await store.start()

        #expect(store.snapshot.connectionState == .connected)
        #expect(store.snapshot.sessions.isEmpty)
        #expect(store.snapshot.counts == StateCounts())
        #expect(store.snapshot.counts.total == 0)
    }

    @Test func snapshotWithOneExplicitRunningSessionExposesItsFieldsAsWorking() async throws {
        let session = makeSession()
        let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: [session]))
        adapter.finish()
        let store = SessionStore(adapter: adapter, now: { fixedNow })

        await store.start()

        #expect(store.snapshot.lastUpdatedAt == fixedNow)
        let entry = try #require(store.snapshot.sessions.first)
        #expect(store.snapshot.sessions.count == 1)
        #expect(entry.id == AgentSessionID("session-1"))
        #expect(entry.session == session)
        #expect(entry.session.workspaceName == "Main Workspace")
        #expect(entry.session.tabName == "Backend")
        #expect(entry.session.paneID == PaneID("pane-1"))
        #expect(entry.session.paneLabel == "Pane 1")
        #expect(entry.session.agentKind == "claude")
        #expect(entry.session.displayName == "Claude Code")
        #expect(entry.session.rawState == "running")
        #expect(entry.session.stateSource == .explicitEvent)
        #expect(entry.normalizedState == .working)
        #expect(entry.conflictNote == nil)
        #expect(store.snapshot.counts.working == 1)
        #expect(store.snapshot.counts.total == 1)
    }

    @Test func sessionAddedEventAppearsInStoreSnapshot() async {
        let adapter = FakeHerdrAdapter(snapshot: .empty)
        adapter.send(.sessionAdded(makeSession(id: "session-2", paneID: "pane-2")))
        adapter.finish()
        let store = SessionStore(adapter: adapter)

        await store.start()

        #expect(store.snapshot.sessions.map(\.id) == [AgentSessionID("session-2")])
        #expect(store.snapshot.counts.total == 1)
    }

    @Test func sessionRemovedEventRemovesThePaneFromStoreSnapshot() async {
        let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: [
            makeSession(id: "session-1", paneID: "pane-1"),
            makeSession(id: "session-2", paneID: "pane-2"),
        ]))
        adapter.send(.sessionRemoved(AgentSessionID("session-1")))
        adapter.finish()
        let store = SessionStore(adapter: adapter)

        await store.start()

        #expect(store.snapshot.sessions.map(\.id) == [AgentSessionID("session-2")])
        #expect(store.snapshot.counts.total == 1)
    }

    @Test func sessionStateChangedEventUpdatesRawStateOfThatSessionOnly() async throws {
        let changedAt = Date(timeIntervalSince1970: 1_750_000_000)
        let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: [
            makeSession(id: "session-1", paneID: "pane-1", rawState: "running"),
            makeSession(id: "session-2", paneID: "pane-2", rawState: "running"),
        ]))
        adapter.send(.sessionStateChanged(
            AgentSessionID("session-1"),
            rawState: "waiting_approval",
            stateSource: .explicitEvent,
            updatedAt: changedAt
        ))
        adapter.finish()
        let store = SessionStore(adapter: adapter)

        await store.start()

        let first = try #require(store.snapshot.sessions.first { $0.id == AgentSessionID("session-1") })
        let second = try #require(store.snapshot.sessions.first { $0.id == AgentSessionID("session-2") })
        #expect(first.session.rawState == "waiting_approval")
        #expect(first.session.updatedAt == changedAt)
        #expect(second.session.rawState == "running")
        #expect(store.snapshot.counts.total == 2)
    }

    @Test func connectionChangedEventUpdatesConnectionStateAndKeepsLastSessions() async {
        let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: [makeSession()]))
        adapter.send(.connectionChanged(.disconnected))
        adapter.finish()
        let times = LockedTimes(fixedNow, fixedNow.addingTimeInterval(60))
        let store = SessionStore(adapter: adapter, now: { times.next() })

        await store.start()

        #expect(store.snapshot.connectionState == .disconnected)
        #expect(store.snapshot.sessions.count == 1)
        #expect(store.snapshot.lastUpdatedAt == fixedNow)
    }
}

private struct HerdrUnavailable: Error {}

@MainActor
struct SessionStoreSnapshotFailureTests {
    @Test func snapshotFailureLeavesStoreDisconnectedWithoutLastUpdate() async {
        let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: [makeSession()]))
        await adapter.setSnapshotError(HerdrUnavailable())
        adapter.finish()
        let store = SessionStore(adapter: adapter)

        await store.start()

        #expect(store.snapshot.connectionState == .disconnected)
        #expect(store.snapshot.sessions.isEmpty)
        #expect(store.snapshot.lastUpdatedAt == nil)
    }
}

/// 依序回傳預設時間的測試時鐘。
private final class LockedTimes: @unchecked Sendable {
    private let lock = NSLock()
    private var times: [Date]

    init(_ times: Date...) { self.times = times }

    func next() -> Date {
        lock.withLock { times.count > 1 ? times.removeFirst() : times[0] }
    }
}
