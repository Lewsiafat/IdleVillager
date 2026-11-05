import Foundation
import Testing
import IdleVillagerCore

private struct SnapshotFailed: Error {}

private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

private func session(_ id: String, rawState: String = "working") -> AgentSession {
    AgentSession(
        workspaceID: WorkspaceID("ws-1"),
        workspaceName: "Main Workspace",
        tabID: TabID("tab-1"),
        tabName: "Tab 1",
        paneID: PaneID("pane-\(id)"),
        paneLabel: "Pane \(id)",
        agentSessionID: AgentSessionID(id),
        agentKind: "claude",
        displayName: "Claude Code",
        rawState: rawState,
        updatedAt: fixedNow,
        stateSource: .explicitEvent
    )
}

/// 以 Fake Adapter 餵入快照與事件，回傳 Store 處理完後的 Popover 清單模型。`snapshotFails` 為 true 時快照讀取一律失敗。
@MainActor
private func listModel(
    of sessions: [AgentSession],
    events: [AdapterEvent] = [],
    snapshotFails: Bool = false
) async -> SessionListModel {
    let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: sessions))
    if snapshotFails { await adapter.setSnapshotError(SnapshotFailed()) }
    for event in events { adapter.send(event) }
    adapter.finish()
    let store = SessionStore(adapter: adapter, now: { fixedNow })
    await store.start()
    return SessionListModel(snapshot: store.snapshot)
}

private func containsDigit(_ text: String) -> Bool {
    text.contains { $0.isNumber }
}

// MARK: - Popover 標題的連線狀態

@MainActor
struct PopoverHeaderStatusTests {
    @Test func neverConnectedShowsNotConnectedInsteadOfZero() async {
        let model = await listModel(of: [], snapshotFails: true)

        #expect(model.headerStatusText == "未連線")
        #expect(containsDigit(model.headerStatusText) == false)
    }

    @Test func disconnectedAfterDataShowsDisconnectedInsteadOfTheStaleCount() async {
        let model = await listModel(
            of: [session("a"), session("b"), session("c")],
            events: [.connectionChanged(.disconnected)]
        )

        #expect(model.headerStatusText == "已斷線")
        #expect(containsDigit(model.headerStatusText) == false)
    }

    @Test func reconnectingShowsReconnectingWithoutNumbers() async {
        let model = await listModel(of: [session("a")], events: [.connectionChanged(.reconnecting)])

        #expect(model.headerStatusText == "重新連線中")
        #expect(containsDigit(model.headerStatusText) == false)
    }

    @Test func connectedWithZeroAgentsKeepsTheZeroAgentPresentation() async {
        let model = await listModel(of: [])

        #expect(model.headerStatusText == "0 個 Agent")
        #expect(model.emptyStateText == "目前沒有 Agent Session")
    }

    @Test func connectedShowsTheTotalAgentCount() async {
        let model = await listModel(of: [session("a"), session("b", rawState: "idle")])

        #expect(model.headerStatusText == "2 個 Agent")
    }
}

// MARK: - 聚焦失敗訊息不提來源名稱

struct FocusFailureMessageTests {
    @Test(arguments: [
        FocusFailureReason.targetNotFound, .unsupported, .disconnected, .windowNotBroughtToFront, .demoMode,
    ])
    func messageDoesNotMentionHerdr(reason: FocusFailureReason) {
        let failure = FocusFailure(sessionID: AgentSessionID("s"), paneID: PaneID("p"), reason: reason)

        #expect(failure.message.contains("Herdr") == false)
        #expect(failure.bannerText.contains("Herdr") == false)
    }
}
