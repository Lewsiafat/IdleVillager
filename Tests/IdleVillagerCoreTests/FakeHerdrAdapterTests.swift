import Testing
import IdleVillagerCore

struct FakeHerdrAdapterTests {
    @Test func defaultSourceIsDemoDataAndDefaultFocusFailsAsDemoMode() async {
        let adapter = FakeHerdrAdapter(snapshot: .demo)

        let result = await adapter.focus(sessionID: AgentSessionID("demo-1"), paneID: PaneID("demo-pane-1"))

        #expect(adapter.sourceDescription == SourceDescription.demo)
        #expect(result == .failure(.demoMode))
        #expect(await adapter.focusRequests == [
            .init(sessionID: AgentSessionID("demo-1"), paneID: PaneID("demo-pane-1")),
        ])
    }

    @Test func focusRecordsEachRequestAndReturnsTheConfiguredResult() async {
        let adapter = FakeHerdrAdapter(focusResult: .success)

        let first = await adapter.focus(sessionID: AgentSessionID("session-1"), paneID: PaneID("pane-1"))
        await adapter.setFocusResult(.failure(.targetNotFound))
        let second = await adapter.focus(sessionID: AgentSessionID("session-2"), paneID: PaneID("pane-2"))

        #expect(first == .success)
        #expect(second == .failure(.targetNotFound))
        #expect(await adapter.focusRequests == [
            .init(sessionID: AgentSessionID("session-1"), paneID: PaneID("pane-1")),
            .init(sessionID: AgentSessionID("session-2"), paneID: PaneID("pane-2")),
        ])
    }
}
