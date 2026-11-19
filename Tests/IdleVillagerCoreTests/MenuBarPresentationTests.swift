import Foundation
import Testing
import IdleVillagerCore

// 選單列呈現（`MenuBarPresentation`）：選單列要畫什麼、哪一格強調、無障礙文字與是否用 template 圖片，都直接對它的輸出斷言。

private func session(
    _ id: String,
    rawState: String,
    agentKind: String = "claude",
    displayName: String = "Claude Code",
    workspaceName: String = "Backend Project",
    tabName: String = "API 開發",
    paneLabel: String = "Pane 1"
) -> AgentSession {
    AgentSession(
        workspaceID: WorkspaceID("ws-1"),
        workspaceName: workspaceName,
        tabID: TabID("tab-1"),
        tabName: tabName,
        paneID: PaneID("pane-\(id)"),
        paneLabel: paneLabel,
        agentSessionID: AgentSessionID(id),
        agentKind: agentKind,
        displayName: displayName,
        rawState: rawState,
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        stateSource: .explicitEvent
    )
}

/// 以 Fake Adapter 餵入 Session 與事件，回傳 Store 處理完後的 snapshot。
@MainActor
private func snapshot(
    of sessions: [AgentSession],
    events: [AdapterEvent] = [],
    errorIDs: Set<String> = []
) async -> StoreSnapshot {
    let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: sessions))
    for event in events { adapter.send(event) }
    adapter.finish()
    let store = SessionStore(adapter: adapter)
    await store.start()
    return store.snapshot.forcingError(for: errorIDs)
}

/// 預設沒有任何品牌素材，與專案目前不附第三方素材的實況一致。
private func noBrandAssets(_ name: String) -> Bool { false }

/// 建立選單列呈現；未指定的設定都是預設值。
private func presentation(
    _ snapshot: StoreSnapshot,
    mode: MenuBarMode = .counts,
    alwaysShowZeroCounts: Bool = false,
    showDoneCount: Bool = false,
    emphasis: MenuBarAlertEmphasis = .none,
    fewCharactersThreshold: Int = MenuBarPresentation.defaultFewCharactersThreshold,
    isBrandAssetAvailable: (String) -> Bool = noBrandAssets
) -> MenuBarPresentation {
    MenuBarPresentation(
        snapshot: snapshot,
        menuBarMode: mode,
        alwaysShowZeroCounts: alwaysShowZeroCounts,
        showDoneCount: showDoneCount,
        emphasis: emphasis,
        fewCharactersThreshold: fewCharactersThreshold,
        isBrandAssetAvailable: isBrandAssetAvailable
    )
}

private func english<R>(_ operation: () throws -> R) rethrows -> R {
    try L10n.withStrings(L10n.strings(for: .english), operation)
}

private func cell(_ state: NormalizedState, _ count: Int, highlighted: Bool = false) -> MenuBarPresentation.CountCell {
    MenuBarPresentation.CountCell(state: state, symbolName: state.symbolName, count: count, isHighlighted: highlighted)
}

private func character(
    _ id: String,
    _ kind: AgentKind,
    _ state: NormalizedState,
    highlighted: Bool = false
) -> MenuBarPresentation.CharacterCell {
    MenuBarPresentation.CharacterCell(
        agentSessionID: AgentSessionID(id),
        agentKind: kind,
        normalizedState: state,
        icon: state.icon,
        isHighlighted: highlighted
    )
}

/// 等核准、幹活、閒置各一個，種類各不同；在少量角色模式下會顯示三個角色。
private let threeKinds: [AgentSession] = [
    session("i1", rawState: "idle", agentKind: "gemini-cli"),
    session("w1", rawState: "working", agentKind: "claude-code"),
    session("a1", rawState: "blocked", agentKind: "codex"),
]

// MARK: - 斷線與零 Agent

@MainActor
struct MenuBarPresentationConnectionTests {
    @Test(arguments: [MenuBarMode.counts, .fewCharacters], [ConnectionState.disconnected, .reconnecting])
    func disconnectionShowsOnlyTheDisconnectedSymbolWithoutAnyNumber(mode: MenuBarMode, connectionState: ConnectionState) async {
        let snapshot = await snapshot(
            of: [session("w1", rawState: "working"), session("a1", rawState: "blocked"), session("d1", rawState: "done")],
            events: [.connectionChanged(connectionState)]
        )

        let result = presentation(snapshot, mode: mode, alwaysShowZeroCounts: true, showDoneCount: true, emphasis: .emphasized)

        #expect(result.content == .disconnected(symbolName: "exclamationmark.triangle"))
        #expect(result.accessibilityText.contains { $0.isNumber } == false)
    }

    @Test func disconnectedAndReconnectingHaveDifferentAccessibilityTexts() async {
        let sessions = [session("w1", rawState: "working")]
        let disconnected = await snapshot(of: sessions, events: [.connectionChanged(.disconnected)])
        let reconnecting = await snapshot(of: sessions, events: [.connectionChanged(.reconnecting)])

        #expect(presentation(disconnected).accessibilityText == "未連線")
        #expect(presentation(reconnecting).accessibilityText == "重新連線中")
        english {
            #expect(presentation(disconnected).accessibilityText == "Not connected")
            #expect(presentation(reconnecting).accessibilityText == "Reconnecting")
        }
    }

    @Test(arguments: [MenuBarMode.counts, .fewCharacters])
    func connectedWithNoSessionsShowsTheZeroAgentsText(mode: MenuBarMode) async {
        let snapshot = await snapshot(of: [])

        let result = presentation(snapshot, mode: mode)

        #expect(result.content == .zeroAgents(text: "0 個 Agent"))
        #expect(result.accessibilityText == "沒有 Agent")
        english {
            let english = presentation(snapshot, mode: mode)
            #expect(english.content == .zeroAgents(text: "0 Agents"))
            #expect(english.accessibilityText == "No Agents")
        }
    }

    @Test func reconnectedReturnsToCounts() async {
        let snapshot = await snapshot(
            of: [session("w1", rawState: "working")],
            events: [.connectionChanged(.disconnected), .connectionChanged(.reconnecting), .connectionChanged(.connected)]
        )

        #expect(presentation(snapshot).content == .counts([cell(.working, 1)], hiddenStatesMarker: nil))
    }
}

// MARK: - 數量模式

@MainActor
struct MenuBarPresentationCountsTests {
    @Test func countsListOnlyVisibleCategoriesInOrderWithTheirSymbols() async {
        let snapshot = await snapshot(of: [
            session("w1", rawState: "working"),
            session("w2", rawState: "working"),
            session("i1", rawState: "idle"),
        ])

        let result = presentation(snapshot)

        #expect(result.content == .counts([cell(.working, 2), cell(.idle, 1)], hiddenStatesMarker: nil))
        #expect(result.usesTemplateImage)
    }

    @Test func accessibilityTextListsEveryVisibleCategoryWithTheListWording() async {
        let snapshot = await snapshot(of: [
            session("w1", rawState: "working"),
            session("w2", rawState: "working"),
            session("w3", rawState: "working"),
            session("a1", rawState: "blocked"),
            session("a2", rawState: "blocked"),
            session("i1", rawState: "idle"),
        ])

        #expect(presentation(snapshot).accessibilityText == "幹活中 3 個，等核准 2 個，閒置 1 個")
        english {
            #expect(presentation(snapshot).accessibilityText == "Working: 3, Needs Approval: 2, Idle: 1")
        }
    }

    @Test func accessibilityTextUsesTheStateShortText() async {
        let snapshot = await snapshot(of: [session("w1", rawState: "working"), session("a1", rawState: "blocked")])

        let text = presentation(snapshot, alwaysShowZeroCounts: true, showDoneCount: true).accessibilityText

        for state in [NormalizedState.working, .needsApproval, .idle, .done] {
            #expect(text.contains(state.shortText), "\(state)")
        }
    }

    @Test func hiddenDoneIsMentionedWhenTheDoneCountIsOff() async {
        let snapshot = await snapshot(of: [session("w1", rawState: "working"), session("d1", rawState: "done")])

        let result = presentation(snapshot, showDoneCount: false)

        #expect(result.content == .counts([cell(.working, 1)], hiddenStatesMarker: "•"))
        #expect(result.accessibilityText == "幹活中 1 個，另有完成、錯誤或訊號不足的 Agent")
        english {
            #expect(presentation(snapshot, showDoneCount: false).accessibilityText
                == "Working: 1, Also Agents that are done, have errors, or have unknown status")
        }
    }

    @Test func hiddenErrorWithTheDoneCountOnLeavesDoneOutOfTheHiddenWording() async {
        // 開啟 Done 小計數但 Done 為 0 且不顯示 0：畫面上看不到 Done 這一格，說法仍依設定值決定。
        let snapshot = await snapshot(of: [session("w1", rawState: "working"), session("u1", rawState: "thinking")])

        let result = presentation(snapshot, showDoneCount: true)

        #expect(result.content == .counts([cell(.working, 1)], hiddenStatesMarker: "•"))
        #expect(result.accessibilityText == "幹活中 1 個，另有錯誤或訊號不足的 Agent")
        english {
            #expect(presentation(snapshot, showDoneCount: true).accessibilityText
                == "Working: 1, Also Agents with errors or unknown status")
        }
    }

    @Test func theDoneCountShowsDoneAfterIdle() async {
        let snapshot = await snapshot(of: [
            session("w1", rawState: "working"),
            session("a1", rawState: "blocked"),
            session("i1", rawState: "idle"),
            session("d1", rawState: "done"),
            session("d2", rawState: "done"),
        ])

        let result = presentation(snapshot, showDoneCount: true)

        #expect(result.content == .counts(
            [cell(.working, 1), cell(.needsApproval, 1), cell(.idle, 1), cell(.done, 2)],
            hiddenStatesMarker: nil
        ))
        #expect(result.accessibilityText == "幹活中 1 個，等核准 1 個，閒置 1 個，完成 2 個")
    }

    @Test func alwaysShowZeroCountsKeepsZeroCategories() async {
        let snapshot = await snapshot(of: [session("w1", rawState: "working")])

        let result = presentation(snapshot, alwaysShowZeroCounts: true)

        #expect(result.content == .counts([cell(.working, 1), cell(.needsApproval, 0), cell(.idle, 0)], hiddenStatesMarker: nil))
        #expect(result.accessibilityText == "幹活中 1 個，等核准 0 個，閒置 0 個")
    }

    @Test func onlyHiddenStatesShowTheMarkerAlone() async {
        let snapshot = await snapshot(of: [session("d1", rawState: "done")])

        let result = presentation(snapshot)

        #expect(result.content == .counts([], hiddenStatesMarker: "•"))
        #expect(result.accessibilityText == "另有完成、錯誤或訊號不足的 Agent")
    }

    @Test func countsModeIsAlwaysATemplateImageEvenWithBrandAssets() async {
        let snapshot = await snapshot(of: [session("w1", rawState: "working")])

        #expect(presentation(snapshot, isBrandAssetAvailable: { _ in true }).usesTemplateImage)
    }
}

// MARK: - 少量角色模式

@MainActor
struct MenuBarPresentationCharactersTests {
    @Test func charactersAreListedInPriorityOrder() async {
        let snapshot = await snapshot(of: threeKinds)

        let result = presentation(snapshot, mode: .fewCharacters)

        #expect(result.content == .characters([
            character("a1", .codex, .needsApproval),
            character("w1", .claude, .working),
            character("i1", .gemini, .idle),
        ]))
    }

    @Test func accessibilityTextListsKindAndStateInPriorityOrder() async {
        let snapshot = await snapshot(of: threeKinds)

        #expect(presentation(snapshot, mode: .fewCharacters).accessibilityText == "Codex 等核准，Claude 幹活中，Gemini 閒置")
        english {
            #expect(presentation(snapshot, mode: .fewCharacters).accessibilityText
                == "Codex: Needs Approval, Claude: Working, Gemini: Idle")
        }
    }

    @Test func unknownKindsAreCalledAgent() async {
        let snapshot = await snapshot(of: [session("e1", rawState: "working", agentKind: "aider")], errorIDs: ["e1"])

        #expect(presentation(snapshot, mode: .fewCharacters).accessibilityText == "Agent 錯誤")
        english {
            #expect(presentation(snapshot, mode: .fewCharacters).accessibilityText == "Agent: Error")
        }
    }

    @Test func sameStateCharactersAreOrderedByPaneLabelNumerically() async {
        let snapshot = await snapshot(of: [
            session("w10", rawState: "working", paneLabel: "Pane 10"),
            session("w2", rawState: "working", paneLabel: "Pane 2"),
            session("e1", rawState: "error", paneLabel: "Pane 3"),
        ], errorIDs: ["e1"])

        #expect(presentation(snapshot, mode: .fewCharacters).content == .characters([
            character("e1", .claude, .error),
            character("w2", .claude, .working),
            character("w10", .claude, .working),
        ]))
    }

    @Test func brandAssetsTurnOffTheTemplateImage() async {
        let snapshot = await snapshot(of: threeKinds)

        let withCodexLogo = presentation(snapshot, mode: .fewCharacters, isBrandAssetAvailable: { $0 == "codex-logo" })
        let withoutAssets = presentation(snapshot, mode: .fewCharacters, isBrandAssetAvailable: noBrandAssets)

        #expect(withCodexLogo.usesTemplateImage == false)
        #expect(withoutAssets.usesTemplateImage)
    }

    @Test func assetsOfKindsNotOnScreenKeepTheTemplateImage() async {
        let snapshot = await snapshot(of: [session("w1", rawState: "working", agentKind: "aider")])

        #expect(presentation(snapshot, mode: .fewCharacters, isBrandAssetAvailable: { _ in true }).usesTemplateImage)
    }

    @Test func accessibilityTextNeverContainsSessionNames() async {
        let snapshot = await snapshot(of: [
            session("w1", rawState: "working", displayName: "Secret Agent Alpha", workspaceName: "Project Phoenix", tabName: "Refactor Tab", paneLabel: "Left Pane"),
            session("a1", rawState: "blocked", agentKind: "codex", displayName: "Codex Beta", workspaceName: "Project Orion", tabName: "Review Tab", paneLabel: "Right Pane"),
        ])

        for mode in MenuBarMode.allCases {
            let text = presentation(snapshot, mode: mode).accessibilityText
            for name in ["Secret Agent Alpha", "Codex Beta", "Project Phoenix", "Project Orion", "Refactor Tab", "Review Tab", "Left Pane", "Right Pane", "w1", "a1"] {
                #expect(!text.contains(name), "\(mode): \(text)")
            }
        }
    }
}

// MARK: - 少量角色門檻

@MainActor
struct MenuBarPresentationThresholdTests {
    @Test func defaultThresholdIsFour() {
        #expect(MenuBarPresentation.defaultFewCharactersThreshold == 4)
    }

    @Test func countsModeNeverShowsCharacters() async {
        let snapshot = await snapshot(of: [session("w1", rawState: "working")])

        #expect(presentation(snapshot, mode: .counts).content == .counts([cell(.working, 1)], hiddenStatesMarker: nil))
    }

    @Test func singleSessionShowsOneCharacter() async {
        let snapshot = await snapshot(of: [session("w1", rawState: "working", agentKind: "codex-cli")])

        #expect(presentation(snapshot, mode: .fewCharacters).content == .characters([character("w1", .codex, .working)]))
    }

    @Test func sessionsEqualToTheThresholdFallBackToCounts() async {
        let snapshot = await snapshot(of: threeKinds + [session("d1", rawState: "done", agentKind: "aider")])

        let result = presentation(snapshot, mode: .fewCharacters)

        #expect(result.content == .counts(
            [cell(.working, 1), cell(.needsApproval, 1), cell(.idle, 1)],
            hiddenStatesMarker: "•"
        ))
        #expect(result.accessibilityText == "幹活中 1 個，等核准 1 個，閒置 1 個，另有完成、錯誤或訊號不足的 Agent")
    }

    @Test func moreSessionsThanTheThresholdFallBackToCounts() async {
        let snapshot = await snapshot(of: [
            session("w1", rawState: "working"),
            session("w2", rawState: "working"),
            session("a1", rawState: "blocked"),
            session("i1", rawState: "idle"),
            session("u1", rawState: "thinking"),
        ])

        guard case .counts = presentation(snapshot, mode: .fewCharacters).content else {
            Issue.record("預期 5 個 Session 回到數量模式")
            return
        }
    }

    @Test func injectedThresholdDecidesWhenToFallBack() async {
        let snapshot = await snapshot(of: threeKinds)

        let thresholdThree = presentation(snapshot, mode: .fewCharacters, fewCharactersThreshold: 3)
        let thresholdFour = presentation(snapshot, mode: .fewCharacters, fewCharactersThreshold: 4)

        guard case .counts = thresholdThree.content else {
            Issue.record("預期門檻 3 時 3 個 Session 回到數量模式")
            return
        }
        guard case .characters(let characters) = thresholdFour.content else {
            Issue.record("預期門檻 4 時 3 個 Session 顯示角色")
            return
        }
        #expect(characters.map(\.agentSessionID) == [AgentSessionID("a1"), AgentSessionID("w1"), AgentSessionID("i1")])
    }
}

// MARK: - 提醒強調

@MainActor
struct MenuBarPresentationEmphasisTests {
    /// 每種正規化狀態各一個 Session（Error 由 helper 製造），讓強調規則對六種狀態都被檢查。
    private func everyState() async -> StoreSnapshot {
        await snapshot(of: [
            session("w1", rawState: "working"),
            session("a1", rawState: "blocked"),
            session("d1", rawState: "done"),
            session("i1", rawState: "idle"),
            session("e1", rawState: "working"),
            session("u1", rawState: "thinking"),
        ], errorIDs: ["e1"])
    }

    @Test func theSingleRuleHighlightsOnlyNeedsApprovalDuringAnAlert() {
        for state in NormalizedState.allCases {
            #expect(MenuBarPresentation.isHighlighted(state, during: .emphasized) == (state == .needsApproval), "\(state)")
            #expect(MenuBarPresentation.isHighlighted(state, during: .none) == false, "\(state)")
        }
    }

    @Test func countsModeHighlightsOnlyTheNeedsApprovalCellDuringAnAlert() async {
        let snapshot = await everyState()

        let result = presentation(snapshot, alwaysShowZeroCounts: true, showDoneCount: true, emphasis: .emphasized)

        #expect(result.content == .counts(
            [cell(.working, 1), cell(.needsApproval, 1, highlighted: true), cell(.idle, 1), cell(.done, 1)],
            hiddenStatesMarker: "•"
        ))
    }

    @Test func fewCharactersModeHighlightsOnlyNeedsApprovalCharactersDuringAnAlert() async {
        let snapshot = await snapshot(of: threeKinds)

        let result = presentation(snapshot, mode: .fewCharacters, emphasis: .emphasized)

        #expect(result.content == .characters([
            character("a1", .codex, .needsApproval, highlighted: true),
            character("w1", .claude, .working),
            character("i1", .gemini, .idle),
        ]))
    }

    @Test(arguments: [MenuBarMode.counts, .fewCharacters])
    func nothingIsHighlightedWithoutAnAlert(mode: MenuBarMode) async {
        let snapshot = await snapshot(of: threeKinds)

        let result = presentation(snapshot, mode: mode, emphasis: .none)

        switch result.content {
        case .counts(let cells, _):
            #expect(!cells.isEmpty)
            #expect(cells.allSatisfy { !$0.isHighlighted })
        case .characters(let characters):
            #expect(!characters.isEmpty)
            #expect(characters.allSatisfy { !$0.isHighlighted })
        default:
            Issue.record("預期數量列或角色列，實際為 \(result.content)")
        }
    }

    @Test func emphasisDoesNotChangeTheAccessibilityText() async {
        let snapshot = await snapshot(of: threeKinds)

        for mode in MenuBarMode.allCases {
            #expect(presentation(snapshot, mode: mode, emphasis: .emphasized).accessibilityText
                == presentation(snapshot, mode: mode, emphasis: .none).accessibilityText)
        }
    }

    @Test func theNewApprovalIsHighlightedOnlyWhileTheTrackerAlerts() async {
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let before = await snapshot(of: [session("s1", rawState: "idle", paneLabel: "Pane 1"), session("s2", rawState: "working", paneLabel: "Pane 2")])
        let after = await snapshot(
            of: [session("s1", rawState: "idle", paneLabel: "Pane 1"), session("s2", rawState: "working", paneLabel: "Pane 2")],
            events: [.sessionStateChanged(AgentSessionID("s1"), rawState: "blocked", stateSource: .explicitEvent,
                                          updatedAt: Date(timeIntervalSince1970: 1_700_000_100))]
        )
        var tracker = ApprovalAlertTracker()
        tracker.observe(needsApprovalCount: before.counts.needsApproval, enabled: true, now: t0)
        tracker.observe(needsApprovalCount: after.counts.needsApproval, enabled: true, now: t0)

        let during = presentation(after, mode: .fewCharacters, emphasis: tracker.emphasis(at: t0))
        let expired = presentation(after, mode: .fewCharacters, emphasis: tracker.emphasis(at: t0.addingTimeInterval(3)))

        guard case .characters(let duringCharacters) = during.content,
              case .characters(let expiredCharacters) = expired.content
        else {
            Issue.record("預期少量角色模式顯示角色")
            return
        }
        #expect(duringCharacters.filter(\.isHighlighted).map(\.agentSessionID) == [AgentSessionID("s1")])
        #expect(expiredCharacters.filter(\.isHighlighted).isEmpty)
    }
}

// MARK: - 使用者設定

@MainActor
struct MenuBarPresentationSettingsTests {
    @Test func settingsDecideTheModeAndTheCountOptions() async {
        let snapshot = await snapshot(of: [session("a1", rawState: "blocked", agentKind: "gemini"), session("d1", rawState: "done")])
        let settings = AppSettings(store: InMemorySettingsStore())

        let counts = MenuBarPresentation(snapshot: snapshot, settings: settings, emphasis: .none, isBrandAssetAvailable: noBrandAssets)
        settings.showDoneCount = true
        let withDone = MenuBarPresentation(snapshot: snapshot, settings: settings, emphasis: .none, isBrandAssetAvailable: noBrandAssets)
        settings.menuBarMode = .fewCharacters
        let characters = MenuBarPresentation(snapshot: snapshot, settings: settings, emphasis: .emphasized, isBrandAssetAvailable: noBrandAssets)

        #expect(counts.content == .counts([cell(.needsApproval, 1)], hiddenStatesMarker: "•"))
        #expect(withDone.content == .counts([cell(.needsApproval, 1), cell(.done, 1)], hiddenStatesMarker: nil))
        #expect(characters.content == .characters([
            character("a1", .gemini, .needsApproval, highlighted: true),
            character("d1", .claude, .done),
        ]))
    }

    @Test func settingsInitAcceptsAnInjectedThreshold() async {
        let snapshot = await snapshot(of: [session("w1", rawState: "working"), session("w2", rawState: "working")])
        let settings = AppSettings(store: InMemorySettingsStore())
        settings.menuBarMode = .fewCharacters

        let result = MenuBarPresentation(
            snapshot: snapshot, settings: settings, emphasis: .none, fewCharactersThreshold: 1, isBrandAssetAvailable: noBrandAssets
        )

        #expect(result.content == .counts([cell(.working, 2)], hiddenStatesMarker: nil))
    }
}
