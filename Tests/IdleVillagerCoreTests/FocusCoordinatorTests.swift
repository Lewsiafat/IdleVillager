import Foundation
import Testing
import IdleVillagerCore

private func makeSession(id: String, tabID: String, paneID: String) -> AgentSession {
    AgentSession(
        workspaceID: WorkspaceID("ws-1"),
        workspaceName: "Main Workspace",
        tabID: TabID(tabID),
        tabName: "Tab \(tabID)",
        paneID: PaneID(paneID),
        paneLabel: "Pane",
        agentSessionID: AgentSessionID(id),
        agentKind: "claude",
        displayName: "Claude Code",
        rawState: "running",
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        stateSource: .explicitEvent
    )
}

/// 以 Fake Adapter 餵入兩個位於不同 Tab 的 Session，啟動 Store 後建立 Coordinator。
@MainActor
private func makeCoordinator(
    focusResult: FocusResult = .success,
    events: [AdapterEvent] = []
) async -> (FakeHerdrAdapter, FocusCoordinator) {
    let adapter = FakeHerdrAdapter(
        snapshot: SessionSnapshot(sessions: [
            makeSession(id: "session-a", tabID: "tab-1", paneID: "pane-a"),
            makeSession(id: "session-b", tabID: "tab-2", paneID: "pane-b"),
        ]),
        focusResult: focusResult
    )
    for event in events { adapter.send(event) }
    adapter.finish()
    let store = SessionStore(adapter: adapter)
    await store.start()
    return (adapter, FocusCoordinator(store: store, adapter: adapter))
}

@MainActor
struct FocusCoordinatorTests {
    @Test func focusSendsTheRowsSessionIDAndPaneIDToTheAdapter() async {
        let (adapter, coordinator) = await makeCoordinator()

        let outcome = await coordinator.focus(sessionID: AgentSessionID("session-b"), paneID: PaneID("pane-b"))

        #expect(outcome == .success)
        #expect(await adapter.focusRequests == [
            FakeHerdrAdapter.FocusRequest(sessionID: AgentSessionID("session-b"), paneID: PaneID("pane-b")),
        ])
    }

    @Test func removedTargetDoesNotCallAdapterAndReportsTargetNotFound() async {
        let (adapter, coordinator) = await makeCoordinator(events: [.sessionRemoved(AgentSessionID("session-a"))])

        let outcome = await coordinator.focus(sessionID: AgentSessionID("session-a"), paneID: PaneID("pane-a"))

        #expect(await adapter.focusRequests.isEmpty)
        let expected = FocusFailure(
            sessionID: AgentSessionID("session-a"),
            paneID: PaneID("pane-a"),
            reason: .targetNotFound
        )
        #expect(outcome == .failure(expected))
        #expect(coordinator.lastFailure == expected)
        #expect(coordinator.lastFailure?.message == "目標已不存在")
    }

    @Test func paneMismatchIsTreatedAsTargetNotFoundWithoutCallingAdapter() async {
        let (adapter, coordinator) = await makeCoordinator()

        let outcome = await coordinator.focus(sessionID: AgentSessionID("session-a"), paneID: PaneID("pane-b"))

        #expect(await adapter.focusRequests.isEmpty)
        #expect(outcome == .failure(FocusFailure(
            sessionID: AgentSessionID("session-a"),
            paneID: PaneID("pane-b"),
            reason: .targetNotFound
        )))
    }

    @Test(arguments: [
        (FocusFailureReason.unsupported, "來源不支援聚焦到這個 Pane", "無法切回：來源不支援聚焦到這個 Pane"),
        (FocusFailureReason.disconnected, "來源已斷線", "無法切回：來源已斷線"),
        (FocusFailureReason.windowNotBroughtToFront, "未能把來源視窗帶到前景", "無法切回：未能把來源視窗帶到前景"),
        (FocusFailureReason.targetNotFound, "目標已不存在", "無法切回：目標已不存在"),
        (FocusFailureReason.demoMode, "示範模式無法切回", "示範模式無法切回"),
    ])
    func adapterFailureBecomesReadableOutcomeAndLastFailure(
        reason: FocusFailureReason,
        message: String,
        bannerText: String
    ) async {
        let (adapter, coordinator) = await makeCoordinator(focusResult: .failure(reason))

        let outcome = await coordinator.focus(sessionID: AgentSessionID("session-a"), paneID: PaneID("pane-a"))

        let expected = FocusFailure(sessionID: AgentSessionID("session-a"), paneID: PaneID("pane-a"), reason: reason)
        #expect(outcome == .failure(expected))
        #expect(coordinator.lastFailure == expected)
        #expect(coordinator.lastFailure?.message == message)
        #expect(coordinator.lastFailure?.bannerText == bannerText)
        #expect(await adapter.focusRequests.count == 1)
    }

    @Test func demoAdapterFocusFailsInsteadOfPretendingSuccess() async {
        let adapter = FakeHerdrAdapter(snapshot: .demo)
        adapter.finish()
        let store = SessionStore(adapter: adapter)
        await store.start()
        let coordinator = FocusCoordinator(store: store, adapter: adapter)

        let outcome = await coordinator.focus(sessionID: AgentSessionID("demo-1"), paneID: PaneID("demo-pane-1"))

        let expected = FocusFailure(
            sessionID: AgentSessionID("demo-1"),
            paneID: PaneID("demo-pane-1"),
            reason: .demoMode
        )
        #expect(outcome == .failure(expected))
        #expect(coordinator.lastFailure == expected)
        #expect(coordinator.lastFailure?.message == "示範模式無法切回")
        #expect(coordinator.lastFailure?.bannerText == "示範模式無法切回")
        #expect(await adapter.focusRequests.count == 1)
    }

    @Test func lastFailureIsNilInitiallyAndClearedAfterSuccess() async {
        let (adapter, coordinator) = await makeCoordinator(focusResult: .failure(.disconnected))
        #expect(coordinator.lastFailure == nil)

        _ = await coordinator.focus(sessionID: AgentSessionID("session-a"), paneID: PaneID("pane-a"))
        #expect(coordinator.lastFailure != nil)

        await adapter.setFocusResult(.success)
        let outcome = await coordinator.focus(sessionID: AgentSessionID("session-a"), paneID: PaneID("pane-a"))

        #expect(outcome == .success)
        #expect(coordinator.lastFailure == nil)
    }

    @Test func consecutiveFocusOnTargetsInDifferentTabsSendsTwoRequestsInOrder() async {
        let (adapter, coordinator) = await makeCoordinator()

        let first = await coordinator.focus(sessionID: AgentSessionID("session-a"), paneID: PaneID("pane-a"))
        let second = await coordinator.focus(sessionID: AgentSessionID("session-b"), paneID: PaneID("pane-b"))

        #expect(first == .success)
        #expect(second == .success)
        #expect(await adapter.focusRequests == [
            FakeHerdrAdapter.FocusRequest(sessionID: AgentSessionID("session-a"), paneID: PaneID("pane-a")),
            FakeHerdrAdapter.FocusRequest(sessionID: AgentSessionID("session-b"), paneID: PaneID("pane-b")),
        ])
    }
}
