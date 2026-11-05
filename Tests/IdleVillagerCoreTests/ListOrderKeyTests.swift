import Testing
@testable import IdleVillagerCore

struct ListOrderKeyTests {
    private func key(_ state: NormalizedState, _ name: String, _ id: String) -> ListOrderKey {
        ListOrderKey(state: state, name: name, id: id)
    }

    @Test func priorityComparesStateThenNumericNameThenID() {
        #expect(ListOrderKey.precedes(key(.needsApproval, "Z", "z"), key(.working, "A", "a")))
        #expect(ListOrderKey.precedes(key(.idle, "Pane 2", "b"), key(.idle, "Pane 10", "a")))
        #expect(ListOrderKey.precedes(key(.idle, "Pane 1", "a"), key(.idle, "Pane 1", "b")))
        #expect(!ListOrderKey.precedes(key(.idle, "Pane 1", "a"), key(.idle, "Pane 1", "a")))
    }

    @Test func workspaceNameIgnoresStateAndComparesNameThenID() {
        #expect(ListOrderKey.precedes(key(.unknown, "Alpha", "z"), key(.needsApproval, "Beta", "a"), by: .workspaceName))
        #expect(ListOrderKey.precedes(key(.unknown, "Same", "a"), key(.needsApproval, "Same", "b"), by: .workspaceName))
    }

    @Test func fixedComparesOnlyID() {
        #expect(ListOrderKey.precedes(key(.unknown, "Z", "a"), key(.needsApproval, "A", "b"), by: .fixed))
        #expect(!ListOrderKey.precedes(key(.needsApproval, "A", "b"), key(.unknown, "Z", "a"), by: .fixed))
    }
}
