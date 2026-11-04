import Testing
import IdleVillagerCore

struct FakeHerdrAdapterTests {
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
