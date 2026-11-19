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
        ("codex-cli", .codex),
        ("Codex_CLI", .codex),
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
        #expect(CharacterPresentation(state: state, previousState: nil, reduceMotion: false, animationsEnabled: true, isVisible: true).pose == expected)
        #expect(CharacterPresentation(state: state, previousState: nil, reduceMotion: true, animationsEnabled: true, isVisible: true).pose == expected)
    }

    // MARK: 過渡

    @Test func workingToDoneCelebratesOnce() {
        let presentation = CharacterPresentation(state: .done, previousState: .working, reduceMotion: false, animationsEnabled: true, isVisible: true)

        #expect(presentation.pose == .delivering)
        #expect(presentation.transition == .celebrateOnce)
        #expect(presentation.transitionParameters == CharacterTransition.celebrateOnce.parameters)
    }

    @Test(arguments: [NormalizedState.needsApproval, .done, .idle, .error, .unknown])
    func doneFromAnyStateOtherThanWorkingDoesNotCelebrate(previous: NormalizedState) {
        #expect(CharacterPresentation(state: .done, previousState: previous, reduceMotion: false, animationsEnabled: true, isVisible: true).transition == nil)
    }

    @Test func doneWithoutPreviousStateDoesNotCelebrate() {
        #expect(CharacterPresentation(state: .done, previousState: nil, reduceMotion: false, animationsEnabled: true, isVisible: true).transition == nil)
    }

    @Test(arguments: [NormalizedState.working, .needsApproval, .done, .error, .unknown])
    func anyOtherStateToIdleSlowsIntoIdle(previous: NormalizedState) {
        let presentation = CharacterPresentation(state: .idle, previousState: previous, reduceMotion: false, animationsEnabled: true, isVisible: true)

        #expect(presentation.pose == .lyingDown)
        #expect(presentation.transition == .slowToIdle)
        #expect(presentation.transitionParameters == CharacterTransition.slowToIdle.parameters)
    }

    @Test func idleStayingIdleHasNoTransition() {
        #expect(CharacterPresentation(state: .idle, previousState: .idle, reduceMotion: false, animationsEnabled: true, isVisible: true).transition == nil)
    }

    @Test func idleWithoutPreviousStateHasNoTransition() {
        #expect(CharacterPresentation(state: .idle, previousState: nil, reduceMotion: false, animationsEnabled: true, isVisible: true).transition == nil)
    }

    @Test(arguments: [NormalizedState.working, .needsApproval, .error, .unknown], NormalizedState.allCases)
    func otherStatesHaveNoTransition(state: NormalizedState, previous: NormalizedState) {
        #expect(CharacterPresentation(state: state, previousState: previous, reduceMotion: false, animationsEnabled: true, isVisible: true).transition == nil)
    }

    @Test(arguments: NormalizedState.allCases, NormalizedState.allCases)
    func reduceMotionNeverOutputsTransition(state: NormalizedState, previous: NormalizedState) {
        #expect(CharacterPresentation(state: state, previousState: previous, reduceMotion: true, animationsEnabled: true, isVisible: true).transition == nil)
    }

    @Test(arguments: NormalizedState.allCases)
    func reduceMotionKeepsTheSameStaticPoseAndLayers(state: NormalizedState) {
        let moving = CharacterPresentation(state: state, previousState: .working, reduceMotion: false, animationsEnabled: true, isVisible: true)
        let still = CharacterPresentation(state: state, previousState: .working, reduceMotion: true, animationsEnabled: true, isVisible: true)

        #expect(still.pose == moving.pose)
        #expect(still.layers == moving.layers)
    }

    // MARK: 播放計畫：循環動作

    @Test(arguments: [
        (NormalizedState.working, CharacterLoop?.some(.workingBob)),
        (.needsApproval, .raisedHandSway),
        (.idle, .idleZzz),
        (.done, nil),
        (.error, nil),
        (.unknown, nil),
    ])
    func eachStateHasItsLoop(state: NormalizedState, expected: CharacterLoop?) {
        #expect(plan(state, previous: nil).loop == expected)
    }

    @Test(arguments: NormalizedState.allCases, Self.previousStates)
    func invisibleCharacterHasNoLoop(state: NormalizedState, previous: NormalizedState?) {
        for (reduceMotion, animationsEnabled) in Self.flagPairs {
            let presentation = plan(state, previous: previous, reduceMotion: reduceMotion,
                                    animationsEnabled: animationsEnabled, isVisible: false)

            #expect(presentation.loop == nil)
        }
    }

    /// Reduce Motion 開啟或動畫關閉（包括選單列的角色）時，只畫靜態姿勢：沒有循環，過渡是不跳、不淡入的那一段。
    @Test(arguments: NormalizedState.allCases, Self.previousStates)
    func reduceMotionOrAnimationsOffPlaysOnlyTheStillTransition(state: NormalizedState, previous: NormalizedState?) {
        for (reduceMotion, animationsEnabled) in [(true, true), (false, false), (true, false)] {
            for isVisible in [true, false] {
                let presentation = plan(state, previous: previous, reduceMotion: reduceMotion,
                                        animationsEnabled: animationsEnabled, isVisible: isVisible)

                #expect(presentation.loop == nil)
                #expect(presentation.transition == nil)
                #expect(presentation.transitionParameters == .noTransition)
            }
        }
    }

    @Test func menuBarCharacterDoesNotAnimate() {
        // 選單列的角色以 animationsEnabled: false 建立。
        let presentation = plan(.done, previous: .working, animationsEnabled: false)

        #expect(presentation.loop == nil)
        #expect(presentation.transition == nil)
    }

    // MARK: 播放計畫：過渡一定合法

    /// 過渡的長度在所有輸入組合下都必須大於 0，沒有過渡時也一樣。
    /// SwiftUI 的 keyframe 動畫以「經過時間 ÷ 全長」算進度，全長為 0 會算出 NaN，
    /// 角色的位移與不透明度變成 NaN，AppKit 檢查到 view 高度為 NaN 就會中止程式（issue #55）。
    @Test(arguments: NormalizedState.allCases, Self.previousStates)
    func transitionDurationIsAlwaysPositive(state: NormalizedState, previous: NormalizedState?) {
        for (reduceMotion, animationsEnabled) in Self.flagPairs {
            for isVisible in [true, false] {
                let presentation = plan(state, previous: previous, reduceMotion: reduceMotion,
                                        animationsEnabled: animationsEnabled, isVisible: isVisible)

                #expect(presentation.transitionParameters.duration > 0)
            }
        }
    }

    @Test(arguments: NormalizedState.allCases, Self.previousStates)
    func noTransitionNeitherJumpsNorFades(state: NormalizedState, previous: NormalizedState?) {
        let presentation = plan(state, previous: previous)
        guard presentation.transition == nil else { return }

        #expect(presentation.transitionParameters.jumpHeight == 0)
        #expect(presentation.transitionParameters.startOpacity == 1)
        #expect(presentation.transitionParameters.duration > 0)
    }

    @Test func celebrateOnceJumpsBrieflyOnce() {
        let parameters = CharacterTransition.celebrateOnce.parameters

        #expect(parameters.duration == 0.5)
        #expect(parameters.jumpHeight == 0.15)
        #expect(parameters.startOpacity == 1)
    }

    @Test func slowToIdleSettlesSlowlyWithoutJumping() {
        let parameters = CharacterTransition.slowToIdle.parameters

        #expect(parameters.duration == 0.8)
        #expect(parameters.jumpHeight == 0)
        #expect(parameters.startOpacity == 0.5)
    }

    // MARK: 測試輔助

    /// 前一狀態的所有可能：沒有前一狀態（第一次出現的 Session）加上六種正規化狀態。
    static let previousStates: [NormalizedState?] = [nil] + NormalizedState.allCases.map(Optional.some)

    /// Reduce Motion 與動畫開關的四種組合。
    static let flagPairs: [(Bool, Bool)] = [(false, true), (true, true), (false, false), (true, false)]

    private func plan(
        _ state: NormalizedState,
        previous: NormalizedState?,
        reduceMotion: Bool = false,
        animationsEnabled: Bool = true,
        isVisible: Bool = true
    ) -> CharacterPresentation {
        CharacterPresentation(state: state, previousState: previous, reduceMotion: reduceMotion,
                              animationsEnabled: animationsEnabled, isVisible: isVisible)
    }

    // MARK: 圖層

    @Test(arguments: NormalizedState.allCases)
    func everyPoseHasTheGenericBodyAndAFace(state: NormalizedState) {
        let layers = CharacterPresentation(state: state, previousState: nil, reduceMotion: false, animationsEnabled: true, isVisible: true).layers

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
        #expect(CharacterPresentation(state: state, previousState: nil, reduceMotion: false, animationsEnabled: true, isVisible: true).layers.prop == expected)
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
        #expect(CharacterPresentation(state: state, previousState: nil, reduceMotion: false, animationsEnabled: true, isVisible: true).layers.effect == expected)
    }

    @Test func raisingHandShowsARaisedHand() {
        let layers = CharacterPresentation(state: .needsApproval, previousState: nil, reduceMotion: false, animationsEnabled: true, isVisible: true).layers

        #expect(layers.hands == .sfSymbol("hand.raised.fill"))
    }

    @Test(arguments: [NormalizedState.error, .unknown], [CharacterLayer.sfSymbol("sparkles"), .sfSymbol("flag.fill")])
    func errorAndUnknownShowNoSuccessImagery(state: NormalizedState, successLayer: CharacterLayer) {
        let layers = CharacterPresentation(state: state, previousState: .working, reduceMotion: false, animationsEnabled: true, isVisible: true).layers

        #expect(layers.prop != successLayer)
        #expect(layers.effect != successLayer)
    }
}
