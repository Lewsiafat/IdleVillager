import Foundation
import Testing
import IdleVillagerCore

private func session(
    _ id: String,
    rawState: String,
    source: StateSource = .explicitEvent,
    workspace: (id: String, name: String) = ("ws-1", "Backend Project"),
    tab: (id: String, name: String) = ("tab-1", "API 開發"),
    paneLabel: String? = nil,
    kind: String = "claude",
    displayName: String = "Claude Code"
) -> AgentSession {
    AgentSession(
        workspaceID: WorkspaceID(workspace.id),
        workspaceName: workspace.name,
        tabID: TabID(tab.id),
        tabName: tab.name,
        paneID: PaneID("pane-\(id)"),
        paneLabel: paneLabel ?? "Pane \(id)",
        agentSessionID: AgentSessionID(id),
        agentKind: kind,
        displayName: displayName,
        rawState: rawState,
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        stateSource: source
    )
}

private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

/// 以 Fake Adapter 餵入 Session 與事件，回傳 Store 處理完後的 Popover 清單模型。
@MainActor
private func listModel(
    of sessions: [AgentSession],
    events: [AdapterEvent] = [],
    sourceDescription: String = SourceDescription.demo,
    errorIDs: Set<String> = []
) async -> SessionListModel {
    let adapter = FakeHerdrAdapter(
        snapshot: SessionSnapshot(sessions: sessions),
        sourceDescription: sourceDescription
    )
    for event in events { adapter.send(event) }
    adapter.finish()
    let store = SessionStore(adapter: adapter, now: { fixedNow })
    await store.start()
    return SessionListModel(snapshot: store.snapshot.forcingError(for: errorIDs))
}

/// Popover 會顯示的文字。用來確認示範模式不會出現「Herdr · 已連線」。
private func popoverTexts(_ model: SessionListModel) -> [String] {
    var texts = [
        model.title,
        model.headerStatusText,
        "來源：\(model.footer.sourceName) · \(model.footer.connectionText)",
        model.footer.lastUpdatedText(now: fixedNow),
    ]
    if let emptyStateText = model.emptyStateText { texts.append(emptyStateText) }
    if let staleNotice = model.footer.staleNotice { texts.append(staleNotice) }
    for workspace in model.workspaces {
        texts.append(workspace.name)
        for tab in workspace.tabs {
            texts.append(tab.name)
            for row in tab.rows {
                texts.append(row.icon)
                texts.append("\(row.displayName) · \(row.paneLabel)")
                texts.append(row.stateText)
                if let detail = row.detail { texts.append(detail) }
            }
        }
    }
    return texts
}

@MainActor
struct SessionListModelTests {
    @Test func titleIsIdleVillagerWithTheTotalAgentCount() async {
        let model = await listModel(of: [
            session("s1", rawState: "working"),
            session("s2", rawState: "idle"),
            session("s3", rawState: "thinking"),
        ])

        #expect(model.title == "IdleVillager")
        #expect(model.agentCount == 3)
    }

    @Test func herdrAppearsOnlyInTheFooterWhenTheAdapterReportsIt() async {
        let model = await listModel(
            of: [session("s1", rawState: "working")],
            sourceDescription: SourceDescription.herdr
        )

        #expect(model.footer == SessionListModel.Footer(
            sourceName: SourceDescription.herdr,
            connectionState: .connected,
            connectionText: "已連線",
            lastUpdatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        ))
        #expect(model.title.contains("Herdr") == false)
        let footerLine = "來源：\(model.footer.sourceName) · \(model.footer.connectionText)"
        #expect(footerLine == "來源：Herdr · 已連線")
        #expect(popoverTexts(model).filter { $0 != footerLine }.contains { $0.contains("Herdr") } == false)
    }

    @Test func fakeAdapterFooterNamesDemoDataAndNeverClaimsHerdrConnected() async {
        let adapter = FakeHerdrAdapter(snapshot: .demo)
        adapter.finish()
        let store = SessionStore(adapter: adapter, now: { fixedNow })
        #expect(store.snapshot.sourceDescription == SourceDescription.demo)

        await store.start()
        let model = SessionListModel(snapshot: store.snapshot)

        #expect(model.footer.sourceName == SourceDescription.demo)
        #expect(model.footer.connectionState == .connected)
        #expect(model.footer.connectionText == "已連線")
        let footerLine = "來源：\(model.footer.sourceName) · \(model.footer.connectionText)"
        #expect(footerLine == "來源：示範資料 · 已連線")
        #expect(popoverTexts(model).contains { $0.contains("Herdr · 已連線") } == false)
        #expect(popoverTexts(model).contains { $0.contains("Herdr") } == false)
    }

    @Test func footerShowsDisconnectionWhileKeepingTheLastSuccessfulUpdate() async {
        let model = await listModel(
            of: [session("s1", rawState: "working")],
            events: [.connectionChanged(.disconnected)]
        )

        #expect(model.footer.sourceName == SourceDescription.demo)
        #expect(model.footer.connectionState == .disconnected)
        #expect(model.footer.connectionText == "已斷線")
        #expect(model.footer.lastUpdatedAt == Date(timeIntervalSince1970: 1_800_000_000))
    }

    @Test func footerShowsReconnecting() async {
        let model = await listModel(
            of: [session("s1", rawState: "working")],
            events: [.connectionChanged(.reconnecting)]
        )

        #expect(model.footer.connectionText == "重新連線中")
    }

    @Test func sessionsAreGroupedByWorkspaceThenTabThenPane() async {
        let backend = (id: "ws-backend", name: "Backend Project")
        let frontend = (id: "ws-frontend", name: "Frontend Project")
        let api = (id: "tab-api", name: "API 開發")
        let tests = (id: "tab-tests", name: "測試")
        let ui = (id: "tab-ui", name: "UI 開發")
        let model = await listModel(of: [
            session("s1", rawState: "working", workspace: backend, tab: api, paneLabel: "Pane 1"),
            session("s2", rawState: "working", workspace: backend, tab: tests, paneLabel: "Pane 1"),
            session("s3", rawState: "working", workspace: frontend, tab: ui, paneLabel: "Pane 1"),
            session("s4", rawState: "working", workspace: backend, tab: api, paneLabel: "Pane 2"),
        ])

        #expect(model.workspaces.map(\.id) == [WorkspaceID("ws-backend"), WorkspaceID("ws-frontend")])
        #expect(model.workspaces.map(\.name) == ["Backend Project", "Frontend Project"])
        #expect(model.workspaces[0].tabs.map(\.id) == [TabID("tab-api"), TabID("tab-tests")])
        #expect(model.workspaces[0].tabs.map(\.name) == ["API 開發", "測試"])
        #expect(model.workspaces[1].tabs.map(\.id) == [TabID("tab-ui")])
        #expect(model.workspaces[0].tabs[0].rows.map(\.id) == [AgentSessionID("s1"), AgentSessionID("s4")])
        #expect(model.workspaces[0].tabs[1].rows.map(\.id) == [AgentSessionID("s2")])
        #expect(model.workspaces[1].tabs[0].rows.map(\.id) == [AgentSessionID("s3")])
    }

    @Test(arguments: [
        ("working", NormalizedState.working, "⚒", "幹活中"),
        ("blocked", NormalizedState.needsApproval, "✋", "等核准"),
        ("done", NormalizedState.done, "✓", "完成"),
        ("idle", NormalizedState.idle, "💤", "閒置"),
        ("error", NormalizedState.error, "!", "錯誤"),
        ("thinking", NormalizedState.unknown, "?", "訊號不足"),
    ])
    func eachRowShowsAgentPaneStateIconAndShortText(
        rawState: String,
        expectedState: NormalizedState,
        expectedIcon: String,
        expectedText: String
    ) async {
        // Herdr 沒有錯誤狀態，Error 列直接在 Store snapshot 上製造。
        let model = await listModel(
            of: [session("s1", rawState: rawState, paneLabel: "Pane 2", kind: "codex", displayName: "Codex")],
            errorIDs: expectedState == .error ? ["s1"] : []
        )

        #expect(model.workspaces[0].tabs[0].rows == [
            SessionListModel.Row(
                id: AgentSessionID("s1"),
                paneID: PaneID("pane-s1"),
                agentKind: .codex,
                displayName: "Codex",
                paneLabel: "Pane 2",
                state: expectedState,
                icon: expectedIcon,
                stateText: expectedText,
                detail: nil
            ),
        ])
    }

    @Test func rowsAreOrderedNeedsApprovalErrorDoneWorkingIdleUnknown() async {
        let model = await listModel(of: [
            session("u1", rawState: "thinking"),
            session("i1", rawState: "idle"),
            session("w1", rawState: "working"),
            session("d1", rawState: "done"),
            session("e1", rawState: "error"),
            session("a1", rawState: "blocked"),
        ], errorIDs: ["e1"])

        #expect(model.workspaces[0].tabs[0].rows.map(\.id.rawValue) == ["a1", "e1", "d1", "w1", "i1", "u1"])
        #expect(model.workspaces[0].tabs[0].rows.map(\.icon) == ["✋", "!", "✓", "⚒", "💤", "?"])
    }

    @Test func groupsContainingNeedsApprovalFloatToTheTopWithTheirContext() async {
        let alpha = (id: "ws-alpha", name: "Alpha")
        let zulu = (id: "ws-zulu", name: "Zulu")
        let model = await listModel(of: [
            session("a-w", rawState: "working", workspace: alpha, tab: ("tab-a1", "A1")),
            session("a-e", rawState: "error", workspace: alpha, tab: ("tab-a2", "A2")),
            session("z-i", rawState: "idle", workspace: zulu, tab: ("tab-z1", "Z1")),
            session("z-w", rawState: "working", workspace: zulu, tab: ("tab-z2", "Z2")),
            session("z-a", rawState: "blocked", workspace: zulu, tab: ("tab-z2", "Z2")),
        ], errorIDs: ["a-e"])

        #expect(model.workspaces.map(\.name) == ["Zulu", "Alpha"])
        #expect(model.workspaces[0].tabs.map(\.name) == ["Z2", "Z1"])
        #expect(model.workspaces[0].tabs[0].rows.map(\.id.rawValue) == ["z-a", "z-w"])
        #expect(model.workspaces[1].tabs.map(\.name) == ["A2", "A1"])
        #expect(model.workspaces.map(\.topState) == [.needsApproval, .error])
        #expect(model.workspaces[0].tabs.map(\.topState) == [.needsApproval, .idle])
    }

    @Test func groupsWithTheSameTopPriorityAreOrderedByName() async {
        let model = await listModel(of: [
            session("s1", rawState: "working", workspace: ("ws-2", "Beta"), tab: ("tab-2b", "Tab B")),
            session("s2", rawState: "working", workspace: ("ws-2", "Beta"), tab: ("tab-2a", "Tab A")),
            session("s3", rawState: "working", workspace: ("ws-1", "Alpha"), tab: ("tab-1", "Tab 1")),
            session("s4", rawState: "working", workspace: ("ws-1", "Alpha"), tab: ("tab-1", "Tab 1"), paneLabel: "Pane 10"),
            session("s5", rawState: "working", workspace: ("ws-1", "Alpha"), tab: ("tab-1", "Tab 1"), paneLabel: "Pane 2"),
        ])

        #expect(model.workspaces.map(\.name) == ["Alpha", "Beta"])
        #expect(model.workspaces[1].tabs.map(\.name) == ["Tab A", "Tab B"])
        #expect(model.workspaces[0].tabs[0].rows.map(\.paneLabel) == ["Pane 2", "Pane 10", "Pane s3"])
    }

    @Test func twoAgentsOfTheSameKindInOneTabAreDistinguishedByIDAndPaneLabel() async {
        let model = await listModel(of: [
            session("claude-a", rawState: "working", paneLabel: "Pane 1", kind: "claude", displayName: "Claude Code"),
            session("claude-b", rawState: "working", paneLabel: "Pane 2", kind: "claude", displayName: "Claude Code"),
        ])

        let rows = model.workspaces[0].tabs[0].rows
        #expect(model.workspaces[0].tabs.count == 1)
        #expect(rows.map(\.id) == [AgentSessionID("claude-a"), AgentSessionID("claude-b")])
        #expect(rows.map(\.paneLabel) == ["Pane 1", "Pane 2"])
        #expect(rows.map(\.paneID) == [PaneID("pane-claude-a"), PaneID("pane-claude-b")])
        #expect(rows.map(\.agentKind) == [.claude, .claude])
        #expect(rows.map(\.displayName) == ["Claude Code", "Claude Code"])
    }

    @Test func unknownRowsAreListedLastWithQuestionMarkAndAreNeverHidden() async {
        let model = await listModel(of: [
            session("u1", rawState: "idle", source: .indirectSignal, workspace: ("ws-quiet", "Quiet")),
            session("w1", rawState: "working"),
        ])

        #expect(model.agentCount == 2)
        #expect(model.workspaces.map(\.name) == ["Backend Project", "Quiet"])
        let unknown = model.workspaces[1].tabs[0].rows
        #expect(unknown.map(\.id) == [AgentSessionID("u1")])
        #expect(unknown.map(\.icon) == ["?"])
        #expect(unknown.map(\.stateText) == ["訊號不足"])
    }

    @Test func conflictingSignalsShowTheConflictNoteAsDetail() async {
        let model = await listModel(of: [session("c1", rawState: "working|idle")])

        let row = model.workspaces[0].tabs[0].rows[0]
        #expect(row.state == .unknown)
        #expect(row.icon == "?")
        #expect(row.stateText == "訊號不足")
        #expect(row.detail == "訊號衝突：Working、Idle")
    }

    @Test func aSessionTurningToNeedsApprovalFloatsItsGroupsToTheTop() async {
        let model = await listModel(
            of: [
                session("a-w", rawState: "working", workspace: ("ws-a", "Alpha"), tab: ("tab-a", "Tab A")),
                session("b-w", rawState: "working", workspace: ("ws-b", "Beta"), tab: ("tab-b1", "Tab B1")),
                session("b-i", rawState: "idle", workspace: ("ws-b", "Beta"), tab: ("tab-b2", "Tab B2")),
            ],
            events: [
                .sessionStateChanged(
                    AgentSessionID("b-i"),
                    rawState: "blocked",
                    stateSource: .explicitEvent,
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
                ),
            ]
        )

        #expect(model.workspaces.map(\.name) == ["Beta", "Alpha"])
        #expect(model.workspaces[0].tabs.map(\.name) == ["Tab B2", "Tab B1"])
        #expect(model.workspaces[0].tabs[0].rows.map(\.stateText) == ["等核准"])
    }

    @Test func closingThePaneRemovesTheRowAndEmptyGroups() async {
        let model = await listModel(
            of: [
                session("s1", rawState: "working", workspace: ("ws-a", "Alpha"), tab: ("tab-a", "Tab A")),
                session("s2", rawState: "idle", workspace: ("ws-b", "Beta"), tab: ("tab-b", "Tab B")),
            ],
            events: [.sessionRemoved(AgentSessionID("s2"))]
        )

        #expect(model.agentCount == 1)
        #expect(model.workspaces.map(\.name) == ["Alpha"])
    }

    @Test func zeroAgentsGivesAnEmptyListWithAZeroCount() async {
        let model = await listModel(of: [])

        #expect(model.agentCount == 0)
        #expect(model.workspaces.isEmpty)
        #expect(model.footer.connectionText == "已連線")
    }
}
