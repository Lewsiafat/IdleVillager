import Testing
@testable import IdleVillagerCore

struct StateTintTests {
    @Test(arguments: [
        (NormalizedState.working, StateTint.green),
        (.needsApproval, .orange),
        (.done, .yellow),
        (.error, .red),
        (.idle, .gray),
        (.unknown, .gray),
    ])
    func eachStateMapsToItsCapsuleTint(state: NormalizedState, tint: StateTint) {
        #expect(state.tint == tint)
    }
}
