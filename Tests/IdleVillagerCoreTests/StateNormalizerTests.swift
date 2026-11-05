import Testing
import IdleVillagerCore

struct StateNormalizerTests {
    @Test(arguments: [
        ("working", NormalizedState.working),
        ("running", .working),
        ("busy", .working),
        ("needsApproval", .needsApproval),
        ("waiting_for_approval", .needsApproval),
        ("awaiting_input", .needsApproval),
        ("done", .done),
        ("completed", .done),
        ("idle", .idle),
        ("error", .error),
        ("failed", .error),
    ])
    func explicitEventRawStateMapsToItsNormalizedState(rawState: String, expected: NormalizedState) {
        let result = StateNormalizer.normalize(rawState: rawState, stateSource: .explicitEvent)

        #expect(result.state == expected)
        #expect(result.conflictNote == nil)
    }

    @Test(arguments: [
        ("RUNNING", NormalizedState.working),
        ("Waiting-For-Approval", .needsApproval),
        ("needsapproval", .needsApproval),
        ("Awaiting-Input", .needsApproval),
    ])
    func matchingIgnoresCaseAndTreatsHyphenAsUnderscore(rawState: String, expected: NormalizedState) {
        #expect(StateNormalizer.normalize(rawState: rawState, stateSource: .explicitEvent).state == expected)
    }

    @Test(arguments: [StateSource.indirectSignal, .unspecified], ["idle", "working", "needsApproval", "done", "error"])
    func nonExplicitSourceIsAlwaysUnknownNeverIdle(stateSource: StateSource, rawState: String) {
        let result = StateNormalizer.normalize(rawState: rawState, stateSource: stateSource)

        #expect(result.state == .unknown)
        #expect(result.conflictNote == nil)
    }

    @Test(arguments: ["", "   ", "thinking", "process_alive", "cpu_low", "blocked", "BLOCKED"])
    func unmappableExplicitRawStateIsUnknownWithoutConflictNote(rawState: String) {
        let result = StateNormalizer.normalize(rawState: rawState, stateSource: .explicitEvent)

        #expect(result.state == .unknown)
        #expect(result.conflictNote == nil)
    }

    @Test func conflictingSignalsAreUnknownWithANoteNamingOnlyTheStates() {
        let result = StateNormalizer.normalize(rawState: "busy|idle", stateSource: .explicitEvent)

        #expect(result.state == .unknown)
        #expect(result.conflictNote == "訊號衝突：Working、Idle")
    }

    @Test(arguments: ["needsApproval|idle", "idle|waiting_for_approval", "awaiting_input|idle|awaiting-input"])
    func needsApprovalTakesPriorityOverIdleInTheSameSession(rawState: String) {
        let result = StateNormalizer.normalize(rawState: rawState, stateSource: .explicitEvent)

        #expect(result.state == .needsApproval)
        #expect(result.conflictNote == nil)
    }

    @Test func blockedAlongsideIdleIsUnknownNotNeedsApproval() {
        let result = StateNormalizer.normalize(rawState: "blocked|idle", stateSource: .explicitEvent)

        #expect(result.state == .unknown)
        #expect(result.conflictNote == nil)
    }

    @Test func signalsThatMapToTheSameStateAreNotAConflict() {
        let result = StateNormalizer.normalize(rawState: "running|busy", stateSource: .explicitEvent)

        #expect(result.state == .working)
        #expect(result.conflictNote == nil)
    }

    @Test func doneAlongsideIdleIsAConflictNotIdle() {
        let result = StateNormalizer.normalize(rawState: "completed|idle", stateSource: .explicitEvent)

        #expect(result.state == .unknown)
        #expect(result.conflictNote == "訊號衝突：Done、Idle")
    }

    @Test func conflictNoteListsEveryConflictingStateWithoutRawText() {
        let result = StateNormalizer.normalize(rawState: "FAILED|running|NeedsApproval", stateSource: .explicitEvent)

        #expect(result.state == .unknown)
        #expect(result.conflictNote == "訊號衝突：Working、Needs Approval、Error")
    }
}
