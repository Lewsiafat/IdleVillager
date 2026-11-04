import Testing
import IdleVillagerCore

struct BrandBodyTests {
    // MARK: 品牌資產名稱

    @Test(arguments: [
        (AgentKind.claude, String?.some("claude-logo")),
        (.codex, "codex-logo"),
        (.gemini, "gemini-logo"),
        (.generic, nil),
    ])
    func eachAgentKindHasItsAssetName(kind: AgentKind, expected: String?) {
        #expect(BrandBody.assetName(for: kind) == expected)
    }

    // MARK: 解析與備援

    @Test(arguments: [
        (AgentKind.claude, BrandBody.asset(name: "claude-logo")),
        (.codex, .asset(name: "codex-logo")),
        (.gemini, .asset(name: "gemini-logo")),
    ])
    func brandedKindUsesItsAssetWhenAvailable(kind: AgentKind, expected: BrandBody) {
        #expect(BrandBody.resolve(agentKind: kind, isAssetAvailable: { _ in true }) == expected)
    }

    @Test(arguments: [AgentKind.claude, .codex, .gemini, .generic])
    func missingAssetFallsBackToGeneric(kind: AgentKind) {
        #expect(BrandBody.resolve(agentKind: kind, isAssetAvailable: { _ in false }) == .generic)
    }

    @Test func genericKindIsGenericEvenWhenEveryAssetExists() {
        #expect(BrandBody.resolve(agentKind: .generic, isAssetAvailable: { _ in true }) == .generic)
    }

    @Test func onlyTheAvailableAssetIsUsed() {
        let available: Set<String> = ["gemini-logo"]
        let check: (String) -> Bool = { available.contains($0) }

        #expect(BrandBody.resolve(agentKind: .gemini, isAssetAvailable: check) == .asset(name: "gemini-logo"))
        #expect(BrandBody.resolve(agentKind: .claude, isAssetAvailable: check) == .generic)
        #expect(BrandBody.resolve(agentKind: .codex, isAssetAvailable: check) == .generic)
    }

    // MARK: 帶入角色呈現

    @Test(arguments: NormalizedState.allCases)
    func brandBodyStaysTheSameInEveryState(state: NormalizedState) {
        let presentation = CharacterPresentation(
            state: state, previousState: .working, reduceMotion: false,
            agentKind: .claude, isBrandAssetAvailable: { _ in true }
        )

        #expect(presentation.brandBody == .asset(name: "claude-logo"))
    }

    @Test(arguments: NormalizedState.allCases)
    func brandedPresentationKeepsTheSamePoseLayersAndTransition(state: NormalizedState) {
        let generic = CharacterPresentation(state: state, previousState: .working, reduceMotion: false)
        let branded = CharacterPresentation(
            state: state, previousState: .working, reduceMotion: false,
            agentKind: .codex, isBrandAssetAvailable: { _ in true }
        )

        #expect(branded.pose == generic.pose)
        #expect(branded.layers == generic.layers)
        #expect(branded.transition == generic.transition)
    }

    @Test func presentationWithoutAgentKindHasGenericBody() {
        #expect(CharacterPresentation(state: .working, previousState: nil, reduceMotion: false).brandBody == .generic)
    }

    @Test func presentationWithMissingAssetHasGenericBody() {
        let presentation = CharacterPresentation(
            state: .idle, previousState: nil, reduceMotion: false,
            agentKind: .gemini, isBrandAssetAvailable: { _ in false }
        )

        #expect(presentation.brandBody == .generic)
    }
}

struct CharacterDetailTests {
    @Test(arguments: [16.0, 17.0, 18.0])
    func smallSizesDrawOnlyTheBody(size: Double) {
        #expect(CharacterDetail(size: size) == .bodyOnly)
        #expect(CharacterDetail(size: size).drawsOuterLayers == false)
    }

    @Test(arguments: [18.5, 24.0, 28.0, 36.0])
    func largerSizesDrawEveryLayer(size: Double) {
        #expect(CharacterDetail(size: size) == .full)
        #expect(CharacterDetail(size: size).drawsOuterLayers == true)
    }

    @Test func sizesBelowTheSmallRangeStillDrawOnlyTheBody() {
        #expect(CharacterDetail(size: 12) == .bodyOnly)
    }
}
