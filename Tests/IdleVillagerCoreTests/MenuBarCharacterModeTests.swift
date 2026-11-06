import Foundation
import Testing
import IdleVillagerCore

private func session(
    _ id: String,
    rawState: String,
    agentKind: String = "claude",
    paneLabel: String = "Pane 1"
) -> AgentSession {
    AgentSession(
        workspaceID: WorkspaceID("ws-1"),
        workspaceName: "Backend Project",
        tabID: TabID("tab-1"),
        tabName: "API 開發",
        paneID: PaneID("pane-\(id)"),
        paneLabel: paneLabel,
        agentSessionID: AgentSessionID(id),
        agentKind: agentKind,
        displayName: "Agent \(id)",
        rawState: rawState,
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        stateSource: .explicitEvent
    )
}

/// 以 Fake Adapter 餵入 Session 與事件，回傳處理完後的 Store snapshot。
@MainActor
private func snapshot(of sessions: [AgentSession], events: [AdapterEvent] = []) async -> StoreSnapshot {
    let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: sessions))
    for event in events { adapter.send(event) }
    adapter.finish()
    let store = SessionStore(adapter: adapter)
    await store.start()
    return store.snapshot
}

@MainActor
struct MenuBarCharacterModeTests {
    @Test func countsModeAlwaysShowsCounts() async {
        let snapshot = await snapshot(of: [session("w1", rawState: "working")])

        let mode = MenuBarCharacterMode(snapshot: snapshot, menuBarMode: .counts)

        #expect(mode.display == .counts)
    }

    @Test func singleSessionInFewCharactersModeShowsOneCharacter() async {
        let snapshot = await snapshot(of: [session("w1", rawState: "working", agentKind: "codex-cli")])

        let mode = MenuBarCharacterMode(snapshot: snapshot, menuBarMode: .fewCharacters)

        #expect(mode.display == .characters([
            MenuBarCharacterItem(agentSessionID: AgentSessionID("w1"), agentKind: .codex, normalizedState: .working, icon: "⚒"),
        ]))
    }

    @Test func sessionsBelowTheDefaultThresholdShowCharactersInPriorityOrder() async {
        let snapshot = await snapshot(of: [
            session("i1", rawState: "idle", agentKind: "gemini-cli"),
            session("w1", rawState: "working", agentKind: "claude-code"),
            session("a1", rawState: "needsApproval", agentKind: "codex"),
        ])

        let mode = MenuBarCharacterMode(snapshot: snapshot, menuBarMode: .fewCharacters)

        #expect(mode.display == .characters([
            MenuBarCharacterItem(agentSessionID: AgentSessionID("a1"), agentKind: .codex, normalizedState: .needsApproval, icon: "✋"),
            MenuBarCharacterItem(agentSessionID: AgentSessionID("w1"), agentKind: .claude, normalizedState: .working, icon: "⚒"),
            MenuBarCharacterItem(agentSessionID: AgentSessionID("i1"), agentKind: .gemini, normalizedState: .idle, icon: "💤"),
        ]))
    }

    @Test func sessionsEqualToTheDefaultThresholdFallBackToCounts() async {
        let snapshot = await snapshot(of: [
            session("i1", rawState: "idle", agentKind: "gemini-cli"),
            session("w1", rawState: "working", agentKind: "claude-code"),
            session("a1", rawState: "needsApproval", agentKind: "codex"),
            session("d1", rawState: "done", agentKind: "aider"),
        ])

        let mode = MenuBarCharacterMode(snapshot: snapshot, menuBarMode: .fewCharacters)

        #expect(mode.display == .counts)
    }

    @Test func sameStateCharactersAreOrderedByPaneLabelNumerically() async {
        let snapshot = await snapshot(of: [
            session("w10", rawState: "working", paneLabel: "Pane 10"),
            session("w2", rawState: "working", paneLabel: "Pane 2"),
            session("e1", rawState: "error", paneLabel: "Pane 3"),
        ])

        let mode = MenuBarCharacterMode(snapshot: snapshot, menuBarMode: .fewCharacters)

        #expect(mode.display == .characters([
            MenuBarCharacterItem(agentSessionID: AgentSessionID("e1"), agentKind: .claude, normalizedState: .error, icon: "!"),
            MenuBarCharacterItem(agentSessionID: AgentSessionID("w2"), agentKind: .claude, normalizedState: .working, icon: "⚒"),
            MenuBarCharacterItem(agentSessionID: AgentSessionID("w10"), agentKind: .claude, normalizedState: .working, icon: "⚒"),
        ]))
    }

    @Test func moreSessionsThanTheDefaultThresholdFallBackToCounts() async {
        let snapshot = await snapshot(of: [
            session("w1", rawState: "working"),
            session("w2", rawState: "working"),
            session("a1", rawState: "needsApproval"),
            session("i1", rawState: "idle"),
            session("u1", rawState: "thinking"),
        ])

        let mode = MenuBarCharacterMode(snapshot: snapshot, menuBarMode: .fewCharacters)

        #expect(mode.display == .counts)
    }

    @Test func zeroSessionsFallBackToCounts() async {
        let snapshot = await snapshot(of: [])

        let mode = MenuBarCharacterMode(snapshot: snapshot, menuBarMode: .fewCharacters)

        #expect(mode.display == .counts)
    }

    @Test(arguments: [ConnectionState.disconnected, .reconnecting])
    func disconnectionFallsBackToCounts(connectionState: ConnectionState) async {
        let snapshot = await snapshot(
            of: [session("w1", rawState: "working")],
            events: [.connectionChanged(connectionState)]
        )

        let mode = MenuBarCharacterMode(snapshot: snapshot, menuBarMode: .fewCharacters)

        #expect(mode.display == .counts)
    }

    @Test func injectedThresholdDecidesWhenToFallBack() async {
        let snapshot = await snapshot(of: [
            session("w1", rawState: "working"),
            session("a1", rawState: "needsApproval"),
            session("i1", rawState: "idle"),
        ])

        let thresholdThree = MenuBarCharacterMode(snapshot: snapshot, menuBarMode: .fewCharacters, fewCharactersThreshold: 3)
        let thresholdFour = MenuBarCharacterMode(snapshot: snapshot, menuBarMode: .fewCharacters, fewCharactersThreshold: 4)

        #expect(thresholdThree.display == .counts)
        #expect(thresholdFour.display == .characters([
            MenuBarCharacterItem(agentSessionID: AgentSessionID("a1"), agentKind: .claude, normalizedState: .needsApproval, icon: "✋"),
            MenuBarCharacterItem(agentSessionID: AgentSessionID("w1"), agentKind: .claude, normalizedState: .working, icon: "⚒"),
            MenuBarCharacterItem(agentSessionID: AgentSessionID("i1"), agentKind: .claude, normalizedState: .idle, icon: "💤"),
        ]))
    }

    @Test func defaultThresholdIsFour() {
        #expect(MenuBarCharacterMode.defaultFewCharactersThreshold == 4)
    }

    @Test func switchingTheModeInAppSettingsChangesTheDisplay() async {
        let snapshot = await snapshot(of: [session("a1", rawState: "needsApproval", agentKind: "gemini")])
        let settings = AppSettings(store: InMemorySettingsStore())

        let before = MenuBarCharacterMode(snapshot: snapshot, settings: settings)
        settings.menuBarMode = .fewCharacters
        let after = MenuBarCharacterMode(snapshot: snapshot, settings: settings)
        settings.menuBarMode = .counts
        let back = MenuBarCharacterMode(snapshot: snapshot, settings: settings)

        #expect(before.display == .counts)
        #expect(after.display == .characters([
            MenuBarCharacterItem(agentSessionID: AgentSessionID("a1"), agentKind: .gemini, normalizedState: .needsApproval, icon: "✋"),
        ]))
        #expect(back.display == .counts)
    }

    @Test func settingsInitAcceptsAnInjectedThreshold() async {
        let snapshot = await snapshot(of: [
            session("w1", rawState: "working"),
            session("w2", rawState: "working"),
        ])
        let settings = AppSettings(store: InMemorySettingsStore())
        settings.menuBarMode = .fewCharacters

        let mode = MenuBarCharacterMode(snapshot: snapshot, settings: settings, fewCharactersThreshold: 1)

        #expect(mode.display == .counts)
    }
}
