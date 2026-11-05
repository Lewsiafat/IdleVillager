import Foundation
import Testing
import IdleVillagerCore

private func session(
    _ id: String,
    rawState: String,
    source: StateSource = .explicitEvent,
    workspace: String = "ws-1"
) -> AgentSession {
    AgentSession(
        workspaceID: WorkspaceID(workspace),
        workspaceName: "Workspace \(workspace)",
        tabID: TabID("\(workspace)-tab-1"),
        tabName: "Tab 1",
        paneID: PaneID("pane-\(id)"),
        paneLabel: "Pane \(id)",
        agentSessionID: AgentSessionID(id),
        agentKind: "claude",
        displayName: "Claude Code",
        rawState: rawState,
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        stateSource: source
    )
}

@MainActor
private func startedStore(with sessions: [AgentSession], events: [AdapterEvent] = []) async -> SessionStore {
    let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: sessions))
    for event in events { adapter.send(event) }
    adapter.finish()
    let store = SessionStore(adapter: adapter)
    await store.start()
    return store
}

@MainActor
struct StoreNormalizationTests {
    @Test func eachSessionIsCountedInExactlyOneOfTheSixStates() async {
        let store = await startedStore(with: [
            session("w1", rawState: "working"),
            session("w2", rawState: "running"),
            session("w3", rawState: "busy", workspace: "ws-2"),
            session("a1", rawState: "waiting_for_approval"),
            session("a2", rawState: "awaiting_input", workspace: "ws-2"),
            session("d1", rawState: "completed"),
            session("i1", rawState: "idle"),
            session("i2", rawState: "IDLE", workspace: "ws-2"),
            session("e1", rawState: "failed"),
            session("u1", rawState: "idle", source: .indirectSignal),
            session("u2", rawState: "thinking"),
            session("u3", rawState: "working|idle"),
        ])

        let counts = store.snapshot.counts
        #expect(counts.working == 3)
        #expect(counts.needsApproval == 2)
        #expect(counts.done == 1)
        #expect(counts.idle == 2)
        #expect(counts.error == 1)
        #expect(counts.unknown == 3)
        #expect(counts.total == 12)
        #expect(store.snapshot.sessions.count == 12)
    }

    @Test func conflictingSignalsGiveUnknownWithAConflictNoteOnTheStoreSession() async throws {
        let store = await startedStore(with: [session("c1", rawState: "working|idle")])

        let entry = try #require(store.snapshot.sessions.first)
        #expect(entry.normalizedState == .unknown)
        #expect(entry.conflictNote == "訊號衝突：Working、Idle")
        #expect(store.snapshot.counts.unknown == 1)
        #expect(store.snapshot.counts.idle == 0)
        #expect(store.snapshot.counts.working == 0)
    }

    @Test func indirectIdleSignalIsCountedAsUnknownNotIdle() async throws {
        let store = await startedStore(with: [session("s1", rawState: "idle", source: .indirectSignal)])

        let entry = try #require(store.snapshot.sessions.first)
        #expect(entry.normalizedState == .unknown)
        #expect(entry.conflictNote == nil)
        #expect(store.snapshot.counts.idle == 0)
        #expect(store.snapshot.counts.unknown == 1)
    }

    @Test func doneIsNotCountedAsIdle() async {
        let store = await startedStore(with: [
            session("d1", rawState: "done"),
            session("d2", rawState: "completed"),
        ])

        #expect(store.snapshot.counts.done == 2)
        #expect(store.snapshot.counts.idle == 0)
    }

    @Test func sessionWithBothNeedsApprovalAndIdleSignalsIsCountedAsNeedsApproval() async throws {
        let store = await startedStore(with: [session("s1", rawState: "idle|awaiting_input")])

        let entry = try #require(store.snapshot.sessions.first)
        #expect(entry.normalizedState == .needsApproval)
        #expect(entry.conflictNote == nil)
        #expect(store.snapshot.counts.needsApproval == 1)
        #expect(store.snapshot.counts.idle == 0)
    }

    @Test func stateChangedEventIsNormalizedAgain() async throws {
        let store = await startedStore(
            with: [session("s1", rawState: "running")],
            events: [.sessionStateChanged(
                AgentSessionID("s1"),
                rawState: "waiting-for-approval",
                stateSource: .explicitEvent,
                updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
            )]
        )

        let entry = try #require(store.snapshot.sessions.first)
        #expect(entry.normalizedState == .needsApproval)
        #expect(store.snapshot.counts.working == 0)
        #expect(store.snapshot.counts.needsApproval == 1)
    }

    @Test func stateChangedToIndirectSignalFallsBackToUnknown() async throws {
        let store = await startedStore(
            with: [session("s1", rawState: "running")],
            events: [.sessionStateChanged(
                AgentSessionID("s1"),
                rawState: "idle",
                stateSource: .indirectSignal,
                updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
            )]
        )

        #expect(store.snapshot.counts.unknown == 1)
        #expect(store.snapshot.counts.idle == 0)
        #expect(store.snapshot.counts.working == 0)
    }
}
