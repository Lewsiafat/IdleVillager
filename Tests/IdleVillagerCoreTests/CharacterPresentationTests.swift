import Testing
import IdleVillagerCore

struct AgentKindTests {
    @Test(arguments: [
        ("claude", AgentKind.claude),
        ("Claude", .claude),
        ("claude-code", .claude),
        ("CLAUDE_CODE", .claude),
        ("codex", .codex),
        ("Codex", .codex),
        ("openai-codex", .codex),
        ("gemini", .gemini),
        ("GEMINI", .gemini),
        ("gemini-cli", .gemini),
    ])
    func knownRawAgentKindMapsToItsAgentKind(raw: String, expected: AgentKind) {
        #expect(AgentKind(rawAgentKind: raw) == expected)
    }

    @Test(arguments: ["", "aider", "cursor", "claudette", "my-agent", "unknown"])
    func unrecognizedRawAgentKindIsGeneric(raw: String) {
        #expect(AgentKind(rawAgentKind: raw) == .generic)
    }
}

struct CharacterPresentationTests {
    // MARK: 姿勢

    @Test(arguments: [
        (NormalizedState.working, CharacterPose.working),
        (.needsApproval, .raisingHand),
        (.done, .delivering),
        (.idle, .lyingDown),
        (.error, .alert),
        (.unknown, .puzzled),
    ])
    func eachNormalizedStateHasItsPose(state: NormalizedState, expected: CharacterPose) {
        #expect(CharacterPresentation(state: state, previousState: nil, reduceMotion: false).pose == expected)
        #expect(CharacterPresentation(state: state, previousState: nil, reduceMotion: true).pose == expected)
    }

    // MARK: 過渡

    @Test func workingToDoneCelebratesOnce() {
        let presentation = CharacterPresentation(state: .done, previousState: .working, reduceMotion: false)

        #expect(presentation.pose == .delivering)
        #expect(presentation.transition == .celebrateOnce)
    }

    @Test(arguments: [NormalizedState.needsApproval, .done, .idle, .error, .unknown])
    func doneFromAnyStateOtherThanWorkingDoesNotCelebrate(previous: NormalizedState) {
        #expect(CharacterPresentation(state: .done, previousState: previous, reduceMotion: false).transition == nil)
    }

    @Test func doneWithoutPreviousStateDoesNotCelebrate() {
        #expect(CharacterPresentation(state: .done, previousState: nil, reduceMotion: false).transition == nil)
    }

    @Test(arguments: [NormalizedState.working, .needsApproval, .done, .error, .unknown])
    func anyOtherStateToIdleSlowsIntoIdle(previous: NormalizedState) {
        let presentation = CharacterPresentation(state: .idle, previousState: previous, reduceMotion: false)

        #expect(presentation.pose == .lyingDown)
        #expect(presentation.transition == .slowToIdle)
    }

    @Test func idleStayingIdleHasNoTransition() {
        #expect(CharacterPresentation(state: .idle, previousState: .idle, reduceMotion: false).transition == nil)
    }

    @Test func idleWithoutPreviousStateHasNoTransition() {
        #expect(CharacterPresentation(state: .idle, previousState: nil, reduceMotion: false).transition == nil)
    }

    @Test(arguments: [NormalizedState.working, .needsApproval, .error, .unknown], NormalizedState.allCases)
    func otherStatesHaveNoTransition(state: NormalizedState, previous: NormalizedState) {
        #expect(CharacterPresentation(state: state, previousState: previous, reduceMotion: false).transition == nil)
    }

    @Test(arguments: NormalizedState.allCases, NormalizedState.allCases)
    func reduceMotionNeverOutputsTransition(state: NormalizedState, previous: NormalizedState) {
        #expect(CharacterPresentation(state: state, previousState: previous, reduceMotion: true).transition == nil)
    }

    @Test(arguments: NormalizedState.allCases)
    func reduceMotionKeepsTheSameStaticPoseAndLayers(state: NormalizedState) {
        let moving = CharacterPresentation(state: state, previousState: .working, reduceMotion: false)
        let still = CharacterPresentation(state: state, previousState: .working, reduceMotion: true)

        #expect(still.pose == moving.pose)
        #expect(still.layers == moving.layers)
    }

    // MARK: 圖層

    @Test(arguments: NormalizedState.allCases)
    func everyPoseHasTheGenericBodyAndAFace(state: NormalizedState) {
        let layers = CharacterPresentation(state: state, previousState: nil, reduceMotion: false).layers

        #expect(layers.body == .shape(.circle))
        #expect(layers.face != nil)
    }

    @Test(arguments: [
        (NormalizedState.working, CharacterLayer?.some(.sfSymbol("hammer.fill"))),
        (.needsApproval, nil),
        (.done, .sfSymbol("flag.fill")),
        (.idle, .sfSymbol("bed.double.fill")),
        (.error, nil),
        (.unknown, nil),
    ])
    func eachPoseHasItsProp(state: NormalizedState, expected: CharacterLayer?) {
        #expect(CharacterPresentation(state: state, previousState: nil, reduceMotion: false).layers.prop == expected)
    }

    @Test(arguments: [
        (NormalizedState.working, CharacterLayer?.none),
        (.needsApproval, .sfSymbol("exclamationmark.bubble.fill")),
        (.done, .sfSymbol("sparkles")),
        (.idle, .sfSymbol("zzz")),
        (.error, .sfSymbol("exclamationmark.triangle.fill")),
        (.unknown, .sfSymbol("questionmark")),
    ])
    func eachPoseHasItsEffect(state: NormalizedState, expected: CharacterLayer?) {
        #expect(CharacterPresentation(state: state, previousState: nil, reduceMotion: false).layers.effect == expected)
    }

    @Test func raisingHandShowsARaisedHand() {
        let layers = CharacterPresentation(state: .needsApproval, previousState: nil, reduceMotion: false).layers

        #expect(layers.hands == .sfSymbol("hand.raised.fill"))
    }

    @Test(arguments: [NormalizedState.error, .unknown], [CharacterLayer.sfSymbol("sparkles"), .sfSymbol("flag.fill")])
    func errorAndUnknownShowNoSuccessImagery(state: NormalizedState, successLayer: CharacterLayer) {
        let layers = CharacterPresentation(state: state, previousState: .working, reduceMotion: false).layers

        #expect(layers.prop != successLayer)
        #expect(layers.effect != successLayer)
    }
}
