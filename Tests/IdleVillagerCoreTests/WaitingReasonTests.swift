import Foundation
import Testing
import IdleVillagerCore

private let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
private let fixedNow = Date(timeIntervalSince1970: 1_700_000_010)

private func session(_ id: String, rawState: String, waitingReason: String? = nil) -> AgentSession {
    AgentSession(
        workspaceID: WorkspaceID("ws-1"),
        workspaceName: "Backend Project",
        tabID: TabID("tab-1"),
        tabName: "API 開發",
        paneID: PaneID("pane-\(id)"),
        paneLabel: "Pane \(id)",
        agentSessionID: AgentSessionID(id),
        agentKind: "claude",
        displayName: "Claude Code",
        rawState: rawState,
        updatedAt: updatedAt,
        stateSource: .explicitEvent,
        waitingReason: waitingReason
    )
}

private func stateChanged(_ id: String, to rawState: String, waitingReason: String? = nil) -> AdapterEvent {
    .sessionStateChanged(
        AgentSessionID(id), rawState: rawState, stateSource: .explicitEvent, updatedAt: updatedAt,
        waitingReason: waitingReason
    )
}

/// 以 Fake Adapter 餵入 Session 與事件，回傳 Store 處理完後的 snapshot。
@MainActor
private func storeSnapshot(of sessions: [AgentSession], events: [AdapterEvent] = []) async -> StoreSnapshot {
    let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: sessions))
    for event in events { adapter.send(event) }
    adapter.finish()
    let store = SessionStore(adapter: adapter, now: { fixedNow })
    await store.start()
    return store.snapshot
}

private func rows(_ snapshot: StoreSnapshot) -> [SessionListModel.Row] {
    SessionListModel(snapshot: snapshot).workspaces.flatMap(\.tabs).flatMap(\.rows)
}

@MainActor
struct WaitingReasonTests {
    @Test func aWaitingReasonFromTheSnapshotIsShownAsTheRowDetail() async {
        let snapshot = await storeSnapshot(of: [
            session("a1", rawState: "blocked", waitingReason: "等待執行指令核准"),
        ])

        #expect(snapshot.sessions.first?.session.waitingReason == "等待執行指令核准")
        let row = rows(snapshot)[0]
        #expect(row.stateText == "等核准")
        #expect(row.detail == "等待執行指令核准")
    }

    @Test func aRowWithoutWaitingReasonOrConflictHasNoDetail() async {
        let snapshot = await storeSnapshot(of: [session("w1", rawState: "working")])

        #expect(rows(snapshot)[0].detail == nil)
    }

    @Test func aBlankWaitingReasonIsTreatedAsNone() async {
        let snapshot = await storeSnapshot(of: [session("a1", rawState: "blocked", waitingReason: "  \n ")])

        #expect(rows(snapshot)[0].detail == nil)
    }

    @Test func theConflictNoteWinsOverTheWaitingReason() async {
        let snapshot = await storeSnapshot(of: [
            session("c1", rawState: "working|done", waitingReason: "等待執行指令核准"),
        ])

        let row = rows(snapshot)[0]
        #expect(row.state == .unknown)
        #expect(row.detail == "訊號衝突：Working、Done")
    }

    @Test func aStateChangeEventCarriesTheWaitingReason() async {
        let snapshot = await storeSnapshot(
            of: [session("s1", rawState: "working")],
            events: [stateChanged("s1", to: "blocked", waitingReason: "等待檔案寫入權限")]
        )

        #expect(snapshot.sessions.first?.session.waitingReason == "等待檔案寫入權限")
        #expect(rows(snapshot)[0].detail == "等待檔案寫入權限")
    }

    @Test func aStateChangeWithoutWaitingReasonClearsThePreviousOne() async {
        let snapshot = await storeSnapshot(
            of: [session("s1", rawState: "blocked", waitingReason: "等待執行指令核准")],
            events: [stateChanged("s1", to: "working")]
        )

        #expect(snapshot.sessions.first?.session.waitingReason == nil)
        let row = rows(snapshot)[0]
        #expect(row.stateText == "幹活中")
        #expect(row.detail == nil)
    }

    @Test func theDemoSnapshotIncludesANeedsApprovalSessionWithAWaitingReason() async {
        let snapshot = await storeSnapshot(of: SessionSnapshot.demo.sessions)

        let withReason = rows(snapshot).filter { $0.detail != nil }
        #expect(withReason.map(\.id) == [AgentSessionID("demo-2")])
        #expect(withReason.map(\.state) == [.needsApproval])
        #expect(withReason.map(\.detail) == ["等待執行指令核准"])
    }
}
