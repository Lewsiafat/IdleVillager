import Foundation
import Testing
import IdleVillagerCore

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func session(
    _ id: String,
    rawState: String,
    paneLabel: String,
    workspace: String = "ws-1",
    tab: String = "tab-1",
    updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
) -> AgentSession {
    AgentSession(
        workspaceID: WorkspaceID(workspace),
        workspaceName: "Workspace \(workspace)",
        tabID: TabID(tab),
        tabName: "Tab \(tab)",
        paneID: PaneID("pane-\(id)"),
        paneLabel: paneLabel,
        agentSessionID: AgentSessionID(id),
        agentKind: "claude",
        displayName: "Claude Code",
        rawState: rawState,
        updatedAt: updatedAt,
        stateSource: .explicitEvent
    )
}

private func stateChanged(_ id: String, to rawState: String, at updatedAt: Date) -> AdapterEvent {
    .sessionStateChanged(AgentSessionID(id), rawState: rawState, stateSource: .explicitEvent, updatedAt: updatedAt)
}

/// 可在測試中改變時間的時鐘；先依序回傳預設時間，用完後停在最後一個，也可直接設定。
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var times: [Date]

    init(_ times: Date...) { self.times = times }

    func now() -> Date {
        lock.withLock { times.count > 1 ? times.removeFirst() : times[0] }
    }

    func set(_ date: Date) {
        lock.withLock { times = [date] }
    }
}

@MainActor
private func startedStore(
    with sessions: [AgentSession],
    events: [AdapterEvent] = [],
    clock: TestClock = TestClock(t0),
    staleThreshold: TimeInterval? = nil
) async -> SessionStore {
    let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: sessions))
    for event in events { adapter.send(event) }
    adapter.finish()
    let store: SessionStore
    if let staleThreshold {
        store = SessionStore(adapter: adapter, now: { clock.now() }, staleThreshold: staleThreshold)
    } else {
        store = SessionStore(adapter: adapter, now: { clock.now() })
    }
    await store.start()
    return store
}

private func allRows(_ model: SessionListModel) -> [SessionListModel.Row] {
    model.workspaces.flatMap(\.tabs).flatMap(\.rows)
}

private func rowIDs(_ model: SessionListModel) -> [String] {
    allRows(model).map(\.id.rawValue)
}

@MainActor
private func menuBarText(_ store: SessionStore) -> String {
    MenuBarSummaryFormatter.text(for: MenuBarSummary(snapshot: store.snapshot))
}

// MARK: - 狀態變更事件序列

@MainActor
struct StateChangeSequenceTests {
    private let initial = [
        session("a", rawState: "working", paneLabel: "Pane 1"),
        session("b", rawState: "idle", paneLabel: "Pane 2"),
    ]

    /// Session b 依序變成 Working、Needs Approval、Working、Done。
    private let sequence: [AdapterEvent] = [
        stateChanged("b", to: "working", at: Date(timeIntervalSince1970: 1_700_000_010)),
        stateChanged("b", to: "needsApproval", at: Date(timeIntervalSince1970: 1_700_000_020)),
        stateChanged("b", to: "working", at: Date(timeIntervalSince1970: 1_700_000_030)),
        stateChanged("b", to: "done", at: Date(timeIntervalSince1970: 1_700_000_040)),
    ]

    /// 只推送序列的前 `steps` 個事件，觀察每一步之後的 Store。
    private func storeAfter(steps: Int) async -> SessionStore {
        await startedStore(with: initial, events: Array(sequence.prefix(steps)))
    }

    @Test func beforeAnyEventCountsWorkingAndIdle() async {
        let store = await storeAfter(steps: 0)

        #expect(store.snapshot.counts.working == 1)
        #expect(store.snapshot.counts.idle == 1)
        #expect(menuBarText(store) == "⚒ 1  💤 1")
        #expect(rowIDs(SessionListModel(snapshot: store.snapshot)) == ["a", "b"])
    }

    @Test func stepOneBothWorking() async {
        let store = await storeAfter(steps: 1)

        #expect(store.snapshot.counts.working == 2)
        #expect(store.snapshot.counts.idle == 0)
        #expect(store.snapshot.counts.needsApproval == 0)
        #expect(menuBarText(store) == "⚒ 2")
        #expect(rowIDs(SessionListModel(snapshot: store.snapshot)) == ["a", "b"])
    }

    @Test func stepTwoNeedsApprovalGoesFromZeroToOneAndMovesToTop() async {
        let store = await storeAfter(steps: 2)

        #expect(store.snapshot.counts.working == 1)
        #expect(store.snapshot.counts.needsApproval == 1)
        #expect(menuBarText(store) == "⚒ 1  ✋ 1")
        let model = SessionListModel(snapshot: store.snapshot)
        #expect(rowIDs(model) == ["b", "a"])
        #expect(allRows(model).first?.stateText == "等核准")
        #expect(allRows(model).first?.icon == "✋")
    }

    @Test func stepThreeBackToWorkingRestoresOrder() async {
        let store = await storeAfter(steps: 3)

        #expect(store.snapshot.counts.working == 2)
        #expect(store.snapshot.counts.needsApproval == 0)
        #expect(menuBarText(store) == "⚒ 2")
        #expect(rowIDs(SessionListModel(snapshot: store.snapshot)) == ["a", "b"])
    }

    @Test func stepFourDoneIsHiddenFromCountsButRankedAboveWorking() async {
        let store = await storeAfter(steps: 4)

        #expect(store.snapshot.counts.working == 1)
        #expect(store.snapshot.counts.done == 1)
        #expect(store.snapshot.counts.idle == 0)
        #expect(store.snapshot.counts.total == 2)
        #expect(menuBarText(store) == "⚒ 1 •")
        let model = SessionListModel(snapshot: store.snapshot)
        #expect(rowIDs(model) == ["b", "a"])
        #expect(allRows(model).first?.stateText == "完成")
    }

    @Test func stateChangeForUnknownSessionIDIsIgnored() async {
        let store = await startedStore(with: initial, events: [
            stateChanged("ghost", to: "needsApproval", at: Date(timeIntervalSince1970: 1_700_000_010)),
        ])

        #expect(store.snapshot.counts.total == 2)
        #expect(store.snapshot.counts.needsApproval == 0)
        #expect(store.snapshot.sessions.map(\.id.rawValue).sorted() == ["a", "b"])
    }

    @Test func conflictingStateChangeShowsUnknownWithConflictNoteOnRow() async throws {
        let store = await startedStore(with: initial, events: [
            stateChanged("b", to: "working|done", at: Date(timeIntervalSince1970: 1_700_000_010)),
        ])

        #expect(store.snapshot.counts.unknown == 1)
        #expect(store.snapshot.counts.working == 1)
        let row = try #require(allRows(SessionListModel(snapshot: store.snapshot)).first { $0.id.rawValue == "b" })
        #expect(row.state == .unknown)
        #expect(row.icon == "?")
        #expect(row.stateText == "訊號不足")
        #expect(row.detail == "訊號衝突：Working、Done")
    }
}

// MARK: - Session 移除

@MainActor
struct SessionRemovalTests {
    @Test func removingLastSessionOfTabRemovesRowAndEmptyTabGroup() async {
        let store = await startedStore(
            with: [
                session("a", rawState: "working", paneLabel: "Pane 1", tab: "tab-1"),
                session("b", rawState: "idle", paneLabel: "Pane 1", tab: "tab-2"),
            ],
            events: [.sessionRemoved(AgentSessionID("b"))]
        )

        let model = SessionListModel(snapshot: store.snapshot)
        #expect(rowIDs(model) == ["a"])
        #expect(model.workspaces.flatMap(\.tabs).map(\.id.rawValue) == ["tab-1"])
        #expect(model.agentCount == 1)
        #expect(store.snapshot.counts.idle == 0)
        #expect(menuBarText(store) == "⚒ 1")
    }

    @Test func removingLastSessionOfWorkspaceRemovesWorkspaceGroup() async {
        let store = await startedStore(
            with: [
                session("a", rawState: "working", paneLabel: "Pane 1", workspace: "ws-1"),
                session("b", rawState: "needsApproval", paneLabel: "Pane 1", workspace: "ws-2", tab: "tab-9"),
            ],
            events: [.sessionRemoved(AgentSessionID("b"))]
        )

        let model = SessionListModel(snapshot: store.snapshot)
        #expect(model.workspaces.map(\.id.rawValue) == ["ws-1"])
        #expect(store.snapshot.counts.needsApproval == 0)
        #expect(menuBarText(store) == "⚒ 1")
    }

    @Test func removingEverySessionLeavesZeroAgents() async {
        let store = await startedStore(
            with: [session("a", rawState: "working", paneLabel: "Pane 1")],
            events: [.sessionRemoved(AgentSessionID("a"))]
        )

        let model = SessionListModel(snapshot: store.snapshot)
        #expect(model.workspaces.isEmpty)
        #expect(model.agentCount == 0)
        #expect(menuBarText(store) == "0 個 Agent")
    }
}

// MARK: - 過期標記

@MainActor
struct StalenessTests {
    @Test func sessionsAreFreshRightAfterSuccessfulSnapshot() async throws {
        let store = await startedStore(with: [session("a", rawState: "working", paneLabel: "Pane 1")])

        let entry = try #require(store.snapshot.sessions.first)
        #expect(entry.isStale == false)
        let row = try #require(allRows(SessionListModel(snapshot: store.snapshot)).first)
        #expect(row.isStale == false)
        #expect(row.stateText == "幹活中")
    }

    @Test func sessionBecomesStaleOnlyAfterExceedingDefaultSixtySeconds() async throws {
        let clock = TestClock(t0)
        let store = await startedStore(with: [session("a", rawState: "working", paneLabel: "Pane 1")], clock: clock)

        clock.set(t0.addingTimeInterval(60))
        store.refreshStaleness()
        #expect(store.snapshot.sessions.first?.isStale == false)

        clock.set(t0.addingTimeInterval(61))
        store.refreshStaleness()
        #expect(store.snapshot.sessions.first?.isStale == true)
        let row = try #require(allRows(SessionListModel(snapshot: store.snapshot)).first)
        #expect(row.isStale == true)
        #expect(row.state == .working)
        #expect(row.stateText == "幹活中（過期）")
    }

    @Test func staleThresholdCanBeInjected() async {
        let clock = TestClock(t0)
        let store = await startedStore(
            with: [session("a", rawState: "idle", paneLabel: "Pane 1")],
            clock: clock,
            staleThreshold: 10
        )

        clock.set(t0.addingTimeInterval(11))
        store.refreshStaleness()

        #expect(store.snapshot.sessions.first?.isStale == true)
    }

    @Test func laterUpdatedAtFromEventKeepsThatSessionFresh() async throws {
        let clock = TestClock(t0)
        let store = await startedStore(
            with: [
                session("a", rawState: "working", paneLabel: "Pane 1"),
                session("b", rawState: "working", paneLabel: "Pane 2"),
            ],
            events: [stateChanged("b", to: "needsApproval", at: t0.addingTimeInterval(100))],
            clock: clock
        )

        clock.set(t0.addingTimeInterval(120))
        store.refreshStaleness()

        let a = try #require(store.snapshot.sessions.first { $0.id.rawValue == "a" })
        let b = try #require(store.snapshot.sessions.first { $0.id.rawValue == "b" })
        #expect(a.isStale == true)
        #expect(b.isStale == false)
    }

    @Test func stalenessIsReevaluatedWhenAnEventIsHandled() async throws {
        // 第一次讀時鐘是快照時間，第二次是處理事件的時間。
        let clock = TestClock(t0, t0.addingTimeInterval(120))
        let store = await startedStore(
            with: [
                session("a", rawState: "working", paneLabel: "Pane 1"),
                session("b", rawState: "working", paneLabel: "Pane 2"),
            ],
            events: [stateChanged("b", to: "done", at: t0.addingTimeInterval(110))],
            clock: clock
        )

        let a = try #require(store.snapshot.sessions.first { $0.id.rawValue == "a" })
        let b = try #require(store.snapshot.sessions.first { $0.id.rawValue == "b" })
        #expect(a.isStale == true)
        #expect(b.isStale == false)
    }

    @Test func disconnectionMarksEverySessionStale() async {
        let store = await startedStore(
            with: [
                session("a", rawState: "working", paneLabel: "Pane 1"),
                session("b", rawState: "idle", paneLabel: "Pane 2"),
            ],
            events: [.connectionChanged(.disconnected)]
        )

        #expect(store.snapshot.sessions.map(\.isStale) == [true, true])
        #expect(allRows(SessionListModel(snapshot: store.snapshot)).map(\.stateText) == ["幹活中（過期）", "閒置（過期）"])
    }

    @Test func reconnectingMarksSessionsStale() async {
        let store = await startedStore(
            with: [session("a", rawState: "working", paneLabel: "Pane 1")],
            events: [.connectionChanged(.reconnecting)]
        )

        #expect(store.snapshot.sessions.first?.isStale == true)
    }

    @Test func reconnectWithinThresholdRestoresFreshness() async {
        let store = await startedStore(
            with: [session("a", rawState: "working", paneLabel: "Pane 1")],
            events: [.connectionChanged(.disconnected), .connectionChanged(.connected)]
        )

        #expect(store.snapshot.sessions.first?.isStale == false)
    }
}
