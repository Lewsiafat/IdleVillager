import Testing
import IdleVillagerCore

struct StateNormalizerTests {
    @Test func tableContainsExactlyHerdrsFiveAgentStatusValues() {
        #expect(StateNormalizer.rawStateTable == [
            "working": .working,
            "blocked": .needsApproval,
            "done": .done,
            "idle": .idle,
            "unknown": .unknown,
        ])
    }

    @Test(arguments: [
        ("working", NormalizedState.working),
        ("blocked", .needsApproval),
        ("done", .done),
        ("idle", .idle),
        ("unknown", .unknown),
    ])
    func explicitEventRawStateMapsToItsNormalizedState(rawState: String, expected: NormalizedState) {
        let result = StateNormalizer.normalize(rawState: rawState, stateSource: .explicitEvent)

        #expect(result.state == expected)
        #expect(result.conflictNote == nil)
    }

    @Test(arguments: [
        ("WORKING", NormalizedState.working),
        ("Blocked", .needsApproval),
        ("DONE", .done),
        (" idle ", .idle),
    ])
    func matchingIgnoresCaseAndSurroundingWhitespace(rawState: String, expected: NormalizedState) {
        #expect(StateNormalizer.normalize(rawState: rawState, stateSource: .explicitEvent).state == expected)
    }

    @Test(arguments: [StateSource.indirectSignal, .unspecified], ["idle", "working", "blocked", "done"])
    func nonExplicitSourceIsAlwaysUnknownNeverIdle(stateSource: StateSource, rawState: String) {
        let result = StateNormalizer.normalize(rawState: rawState, stateSource: stateSource)

        #expect(result.state == .unknown)
        #expect(result.conflictNote == nil)
    }

    /// 先前暫定表裡的推測值與 Herdr 不存在的錯誤狀態，現在都落到 Unknown，不會被誤判。
    @Test(arguments: [
        "", "   ", "thinking", "process_alive", "cpu_low",
        "running", "busy", "needsApproval", "awaiting_input", "waiting_for_approval", "completed", "error", "failed",
    ])
    func unmappableExplicitRawStateIsUnknownWithoutConflictNote(rawState: String) {
        let result = StateNormalizer.normalize(rawState: rawState, stateSource: .explicitEvent)

        #expect(result.state == .unknown)
        #expect(result.conflictNote == nil)
    }

    @Test func conflictingSignalsAreUnknownWithANoteNamingOnlyTheStates() {
        let result = StateNormalizer.normalize(rawState: "working|idle", stateSource: .explicitEvent)

        #expect(result.state == .unknown)
        #expect(result.conflictNote == "訊號衝突：Working、Idle")
    }

    @Test(arguments: ["blocked|idle", "idle|blocked", "blocked|idle|Blocked"])
    func needsApprovalTakesPriorityOverIdleInTheSameSession(rawState: String) {
        let result = StateNormalizer.normalize(rawState: rawState, stateSource: .explicitEvent)

        #expect(result.state == .needsApproval)
        #expect(result.conflictNote == nil)
    }

    @Test func needsApprovalOverIdleExceptionDoesNotHideOtherConflicts() {
        let result = StateNormalizer.normalize(rawState: "blocked|idle|working", stateSource: .explicitEvent)

        #expect(result.state == .unknown)
        #expect(result.conflictNote == "訊號衝突：Working、Needs Approval")
    }

    @Test func anUnmappableSignalAmongMappableOnesMakesTheWholeSessionUnknown() {
        let result = StateNormalizer.normalize(rawState: "blocked|error", stateSource: .explicitEvent)

        #expect(result.state == .unknown)
        #expect(result.conflictNote == nil)
    }

    @Test func signalsThatMapToTheSameStateAreNotAConflict() {
        let result = StateNormalizer.normalize(rawState: "working|WORKING", stateSource: .explicitEvent)

        #expect(result.state == .working)
        #expect(result.conflictNote == nil)
    }

    @Test func doneAlongsideIdleIsAConflictNotIdle() {
        let result = StateNormalizer.normalize(rawState: "done|idle", stateSource: .explicitEvent)

        #expect(result.state == .unknown)
        #expect(result.conflictNote == "訊號衝突：Done、Idle")
    }

    @Test func conflictNoteListsEveryConflictingStateWithoutRawText() {
        let result = StateNormalizer.normalize(rawState: "DONE|working|Blocked", stateSource: .explicitEvent)

        #expect(result.state == .unknown)
        #expect(result.conflictNote == "訊號衝突：Working、Needs Approval、Done")
    }
}
