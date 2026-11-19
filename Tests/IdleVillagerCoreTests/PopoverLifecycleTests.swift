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
        rawState: "working",
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        stateSource: .explicitEvent
    )
}

/// 以 Fake Adapter 餵入兩個位於不同 Tab 的 Session，啟動 Store 後建立 Popover 生命週期。
@MainActor
private func makeLifecycle(
    focusResult: FocusResult = .success,
    events: [AdapterEvent] = []
) async -> (FakeHerdrAdapter, PopoverLifecycle) {
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
    return (adapter, PopoverLifecycle(focusCoordinator: FocusCoordinator(store: store, adapter: adapter)))
}

private let sessionA = AgentSessionID("session-a")
private let paneA = PaneID("pane-a")

@MainActor
struct PopoverLifecycleTests {
    // MARK: 可見性

    @Test func isNotVisibleBeforeAnyVisibilityReport() async {
        let (_, lifecycle) = await makeLifecycle()

        #expect(lifecycle.isVisible == false)
    }

    @Test func followsReportedVisibility() async {
        let (_, lifecycle) = await makeLifecycle()

        lifecycle.visibilityChanged(true)
        #expect(lifecycle.isVisible)

        lifecycle.visibilityChanged(false)
        #expect(lifecycle.isVisible == false)
    }

    @Test func charactersDoNotMoveWhileThePopoverIsHidden() async {
        let (_, lifecycle) = await makeLifecycle()
        lifecycle.visibilityChanged(true)
        lifecycle.visibilityChanged(false)

        let presentation = CharacterPresentation(
            state: .working, previousState: .idle, reduceMotion: false,
            animationsEnabled: true, isVisible: lifecycle.isVisible
        )

        #expect(presentation.loop == nil)
        #expect(presentation.transition == nil)
    }

    @Test func charactersMoveWhileThePopoverIsVisible() async {
        let (_, lifecycle) = await makeLifecycle()
        lifecycle.visibilityChanged(true)

        let presentation = CharacterPresentation(
            state: .working, previousState: nil, reduceMotion: false,
            animationsEnabled: true, isVisible: lifecycle.isVisible
        )

        #expect(presentation.loop == .workingBob)
    }

    // MARK: 點擊一列

    @Test func successfulFocusRequestsClosingThePopover() async {
        let (adapter, lifecycle) = await makeLifecycle(focusResult: .success)
        lifecycle.visibilityChanged(true)

        let response = await lifecycle.rowClicked(sessionID: sessionA, paneID: paneA)

        #expect(response == .closePopover)
        #expect(lifecycle.focusFailure == nil)
        #expect(await adapter.focusRequests == [FakeHerdrAdapter.FocusRequest(sessionID: sessionA, paneID: paneA)])
    }

    @Test func failedFocusKeepsThePopoverOpenAndPublishesTheFailure() async {
        let (_, lifecycle) = await makeLifecycle(focusResult: .failure(.disconnected))
        lifecycle.visibilityChanged(true)

        let response = await lifecycle.rowClicked(sessionID: sessionA, paneID: paneA)

        #expect(response == .keepOpen)
        #expect(lifecycle.focusFailure == FocusFailure(sessionID: sessionA, paneID: paneA, reason: .disconnected))
        #expect(lifecycle.focusFailure?.bannerText == "無法切回：來源已斷線")
    }

    @Test func demoModeFailureKeepsThePopoverOpenWithTheDemoBanner() async {
        let adapter = FakeHerdrAdapter(snapshot: .demo)
        adapter.finish()
        let store = SessionStore(adapter: adapter)
        await store.start()
        let lifecycle = PopoverLifecycle(focusCoordinator: FocusCoordinator(store: store, adapter: adapter))
        lifecycle.visibilityChanged(true)

        let response = await lifecycle.rowClicked(sessionID: AgentSessionID("demo-1"), paneID: PaneID("demo-pane-1"))

        #expect(response == .keepOpen)
        #expect(lifecycle.focusFailure?.reason == .demoMode)
        #expect(lifecycle.focusFailure?.bannerText == "示範模式無法切回")
    }

    @Test func removedTargetDoesNotCallTheAdapterAndKeepsThePopoverOpen() async {
        let (adapter, lifecycle) = await makeLifecycle(events: [.sessionRemoved(sessionA)])
        lifecycle.visibilityChanged(true)

        let response = await lifecycle.rowClicked(sessionID: sessionA, paneID: paneA)

        #expect(response == .keepOpen)
        #expect(await adapter.focusRequests.isEmpty)
        #expect(lifecycle.focusFailure?.reason == .targetNotFound)
    }

    @Test func dismissingTheFailureClearsIt() async {
        let (_, lifecycle) = await makeLifecycle(focusResult: .failure(.unsupported))
        lifecycle.visibilityChanged(true)
        _ = await lifecycle.rowClicked(sessionID: sessionA, paneID: paneA)

        lifecycle.dismissFocusFailure()

        #expect(lifecycle.focusFailure == nil)
    }

    // MARK: 關閉時的清理

    @Test func reopeningAfterAFailedFocusShowsNoFailure() async {
        let (_, lifecycle) = await makeLifecycle(focusResult: .failure(.demoMode))
        lifecycle.visibilityChanged(true)
        _ = await lifecycle.rowClicked(sessionID: sessionA, paneID: paneA)
        #expect(lifecycle.focusFailure != nil)

        lifecycle.visibilityChanged(false)
        lifecycle.visibilityChanged(true)

        #expect(lifecycle.focusFailure == nil)
    }

    @Test func repeatedVisibleReportsDoNotClearTheFailure() async {
        let (_, lifecycle) = await makeLifecycle(focusResult: .failure(.demoMode))
        lifecycle.visibilityChanged(true)
        _ = await lifecycle.rowClicked(sessionID: sessionA, paneID: paneA)

        lifecycle.visibilityChanged(true)

        #expect(lifecycle.focusFailure != nil)
    }

    @Test func reopeningShowsNoHoveredRow() async {
        let (_, lifecycle) = await makeLifecycle()
        lifecycle.visibilityChanged(true)
        lifecycle.hoverChanged(sessionID: sessionA, isHovered: true)
        #expect(lifecycle.isHovered(sessionA))

        lifecycle.visibilityChanged(false)
        lifecycle.visibilityChanged(true)

        #expect(lifecycle.isHovered(sessionA) == false)
    }

    @Test func hoverReportsWhileHiddenAreIgnored() async {
        let (_, lifecycle) = await makeLifecycle()

        lifecycle.hoverChanged(sessionID: sessionA, isHovered: true)

        #expect(lifecycle.isHovered(sessionA) == false)
    }

    @Test func hoverMovesBetweenRowsWithoutAStaleExitClearingTheNewRow() async {
        let (_, lifecycle) = await makeLifecycle()
        let sessionB = AgentSessionID("session-b")
        lifecycle.visibilityChanged(true)

        lifecycle.hoverChanged(sessionID: sessionA, isHovered: true)
        lifecycle.hoverChanged(sessionID: sessionB, isHovered: true)
        lifecycle.hoverChanged(sessionID: sessionA, isHovered: false)

        #expect(lifecycle.isHovered(sessionA) == false)
        #expect(lifecycle.isHovered(sessionB))
    }

    // MARK: Tab 收合

    @Test func tabsStartExpandedAndToggle() async {
        let (_, lifecycle) = await makeLifecycle()
        let tab = TabID("tab-1")
        #expect(lifecycle.isCollapsed(tab) == false)

        lifecycle.toggleCollapsed(tab)
        #expect(lifecycle.isCollapsed(tab))
        #expect(lifecycle.isCollapsed(TabID("tab-2")) == false)

        lifecycle.toggleCollapsed(tab)
        #expect(lifecycle.isCollapsed(tab) == false)
    }

    @Test func collapseStateIsNotKeptAcrossRestarts() async {
        let (_, first) = await makeLifecycle()
        first.toggleCollapsed(TabID("tab-1"))

        // 重啟等同建立新的 Popover 生命週期；收合狀態只存在記憶體中。
        let (_, restarted) = await makeLifecycle()

        #expect(restarted.isCollapsed(TabID("tab-1")) == false)
    }

    @Test func collapseStateSurvivesClosingAndReopening() async {
        let (_, lifecycle) = await makeLifecycle()
        lifecycle.visibilityChanged(true)
        lifecycle.toggleCollapsed(TabID("tab-1"))

        lifecycle.visibilityChanged(false)
        lifecycle.visibilityChanged(true)

        #expect(lifecycle.isCollapsed(TabID("tab-1")))
    }
}
