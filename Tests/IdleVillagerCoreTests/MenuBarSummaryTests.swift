import Foundation
import Testing
import IdleVillagerCore

private func session(
    _ id: String,
    rawState: String,
    displayName: String = "Claude Code",
    workspaceName: String = "Backend Project",
    tabName: String = "API 開發",
    paneLabel: String = "Pane 1"
) -> AgentSession {
    AgentSession(
        workspaceID: WorkspaceID("ws-1"),
        workspaceName: workspaceName,
        tabID: TabID("tab-1"),
        tabName: tabName,
        paneID: PaneID("pane-\(id)"),
        paneLabel: paneLabel,
        agentSessionID: AgentSessionID(id),
        agentKind: "claude",
        displayName: displayName,
        rawState: rawState,
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        stateSource: .explicitEvent
    )
}

/// 以 Fake Adapter 餵入 Session 與事件，回傳 Store 處理完後的摘要模型。
@MainActor
private func summary(
    of sessions: [AgentSession],
    events: [AdapterEvent] = [],
    alwaysShowZero: Bool = false
) async -> MenuBarSummary {
    let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: sessions))
    for event in events { adapter.send(event) }
    adapter.finish()
    let store = SessionStore(adapter: adapter)
    await store.start()
    return MenuBarSummary(snapshot: store.snapshot, alwaysShowZero: alwaysShowZero)
}

@MainActor
struct MenuBarSummaryTests {
    @Test func showsWorkingNeedsApprovalAndIdleCountsInOrder() async {
        let result = await summary(of: [
            session("w1", rawState: "working"),
            session("w2", rawState: "running"),
            session("w3", rawState: "busy"),
            session("a1", rawState: "needsApproval"),
            session("a2", rawState: "awaiting_input"),
            session("i1", rawState: "idle"),
        ])

        #expect(result.mode == .normal)
        #expect(result.items == [
            MenuBarSummary.Item(state: .working, icon: "⚒", count: 3, isVisible: true),
            MenuBarSummary.Item(state: .needsApproval, icon: "✋", count: 2, isVisible: true),
            MenuBarSummary.Item(state: .idle, icon: "💤", count: 1, isVisible: true),
        ])
        #expect(result.hasHiddenStates == false)
        #expect(MenuBarSummaryFormatter.text(for: result) == "⚒ 3  ✋ 2  💤 1")
    }

    @Test func categoriesWithZeroCountAreHiddenByDefault() async {
        let result = await summary(of: [
            session("w1", rawState: "working"),
            session("w2", rawState: "working"),
            session("i1", rawState: "idle"),
        ])

        #expect(result.items == [
            MenuBarSummary.Item(state: .working, icon: "⚒", count: 2, isVisible: true),
            MenuBarSummary.Item(state: .needsApproval, icon: "✋", count: 0, isVisible: false),
            MenuBarSummary.Item(state: .idle, icon: "💤", count: 1, isVisible: true),
        ])
        #expect(MenuBarSummaryFormatter.text(for: result) == "⚒ 2  💤 1")
    }

    @Test func alwaysShowZeroKeepsEveryCategoryVisible() async {
        let result = await summary(of: [session("w1", rawState: "working")], alwaysShowZero: true)

        #expect(result.items.map(\.isVisible) == [true, true, true])
        #expect(MenuBarSummaryFormatter.text(for: result) == "⚒ 1  ✋ 0  💤 0")
    }

    @Test(arguments: ["done", "failed", "thinking"])
    func doneErrorOrUnknownRaisesTheHiddenStatesFlagAndMarker(hiddenRawState: String) async {
        let result = await summary(of: [
            session("w1", rawState: "working"),
            session("h1", rawState: hiddenRawState),
        ])

        #expect(result.hasHiddenStates == true)
        #expect(MenuBarSummaryFormatter.text(for: result) == "⚒ 1 •")
    }

    @Test(arguments: [ConnectionState.disconnected, .reconnecting])
    func disconnectionShowsDisconnectedModeWithoutAnyNumber(connectionState: ConnectionState) async {
        let result = await summary(
            of: [
                session("w1", rawState: "working"),
                session("a1", rawState: "needsApproval"),
                session("d1", rawState: "done"),
            ],
            events: [.connectionChanged(connectionState)]
        )

        #expect(result.mode == .disconnected)
        #expect(result.items.isEmpty)
        #expect(result.hasHiddenStates == false)
        #expect(MenuBarSummaryFormatter.text(for: result) == "⚠ 斷線")
    }

    @Test func connectedWithNoSessionsShowsZeroAgentsModeDistinctFromDisconnected() async {
        let result = await summary(of: [])

        #expect(result.mode == .zeroAgents)
        #expect(result.items.isEmpty)
        #expect(result.hasHiddenStates == false)
        #expect(MenuBarSummaryFormatter.text(for: result) == "0 個 Agent")
    }

    @Test func reconnectingAfterDisconnectionReturnsToNormalCounts() async {
        let result = await summary(
            of: [session("w1", rawState: "working")],
            events: [.connectionChanged(.disconnected), .connectionChanged(.connected)]
        )

        #expect(result.mode == .normal)
        #expect(MenuBarSummaryFormatter.text(for: result) == "⚒ 1")
    }

    @Test func sixStatesProduceCountsForTheThreeCategoriesAndAHiddenStatesMarker() async {
        let result = await summary(of: [
            session("w1", rawState: "working"),
            session("w2", rawState: "running"),
            session("w3", rawState: "busy"),
            session("a1", rawState: "needsApproval"),
            session("a2", rawState: "awaiting_input"),
            session("i1", rawState: "idle"),
            session("d1", rawState: "done"),
            session("e1", rawState: "error"),
            session("u1", rawState: "running|idle"),
        ])

        #expect(result.mode == .normal)
        #expect(result.items.map(\.count) == [3, 2, 1])
        #expect(result.hasHiddenStates == true)
        #expect(MenuBarSummaryFormatter.text(for: result) == "⚒ 3  ✋ 2  💤 1 •")
    }

    @Test func onlyHiddenStatesShowTheMarkerAlone() async {
        let result = await summary(of: [session("d1", rawState: "done")])

        #expect(result.mode == .normal)
        #expect(result.items.map(\.isVisible) == [false, false, false])
        #expect(MenuBarSummaryFormatter.text(for: result) == "•")
    }

    @Test func menuBarTextNeverContainsSessionNames() async {
        let result = await summary(of: [
            session("w1", rawState: "working", displayName: "Secret Agent Alpha", workspaceName: "Project Phoenix", tabName: "Refactor Tab", paneLabel: "Left Pane"),
            session("a1", rawState: "needsApproval", displayName: "Codex Beta", workspaceName: "Project Phoenix", tabName: "Review Tab", paneLabel: "Right Pane"),
            session("d1", rawState: "done", displayName: "Gemini Gamma", workspaceName: "Project Orion", tabName: "Docs Tab", paneLabel: "Bottom Pane"),
        ])

        let text = MenuBarSummaryFormatter.text(for: result)
        #expect(text == "⚒ 1  ✋ 1 •")
        for name in ["Secret Agent Alpha", "Codex Beta", "Gemini Gamma", "Project Phoenix", "Project Orion", "Refactor Tab", "Review Tab", "Docs Tab", "Left Pane", "Right Pane", "Bottom Pane", "w1", "a1", "d1"] {
            #expect(!text.contains(name))
        }
    }

    @Test func demoSnapshotShowsThreeWorkingTwoNeedsApprovalOneIdleAndTheMarker() async {
        let result = await summary(of: SessionSnapshot.demo.sessions)

        #expect(Set(SessionSnapshot.demo.sessions.map(\.workspaceID)).count == 2)
        #expect(MenuBarSummaryFormatter.text(for: result) == "⚒ 3  ✋ 2  💤 1 •")
    }
}
