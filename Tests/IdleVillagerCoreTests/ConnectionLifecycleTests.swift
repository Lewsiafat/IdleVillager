import Foundation
import Testing
import IdleVillagerCore

// 斷線、重連與零 Agent 的端到端情境：Fake Adapter 推送事件，從摘要模型與清單模型斷言。

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func session(
    _ id: String,
    rawState: String,
    paneLabel: String,
    updatedAt: Date = Date(timeIntervalSince1970: 1_800_000_000)
) -> AgentSession {
    AgentSession(
        workspaceID: WorkspaceID("ws-1"),
        workspaceName: "Backend Project",
        tabID: TabID("tab-1"),
        tabName: "API 開發",
        paneID: PaneID("pane-\(id)"),
        paneLabel: paneLabel,
        agentSessionID: AgentSessionID(id),
        agentKind: "claude",
        displayName: "Claude Code",
        rawState: rawState,
        updatedAt: updatedAt,
        stateSource: .explicitEvent
    )
}

private struct SnapshotUnavailable: Error {}

/// 可在測試中改變時間的時鐘。
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var time: Date

    init(_ time: Date) { self.time = time }

    func now() -> Date { lock.withLock { time } }

    func set(_ date: Date) { lock.withLock { time = date } }
}

private func allRows(_ model: SessionListModel) -> [SessionListModel.Row] {
    model.workspaces.flatMap(\.tabs).flatMap(\.rows)
}

@MainActor
private func menuBarText(_ store: SessionStore) -> String {
    MenuBarSummaryFormatter.text(for: MenuBarSummary(snapshot: store.snapshot))
}

/// 先推送事件、結束串流，再啟動 Store；回傳處理完所有事件後的 Store。
@MainActor
private func finishedStore(
    with sessions: [AgentSession],
    events: [AdapterEvent] = [],
    clock: TestClock = TestClock(t0)
) async -> SessionStore {
    let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: sessions))
    for event in events { adapter.send(event) }
    adapter.finish()
    let store = SessionStore(adapter: adapter, now: { clock.now() })
    await store.start()
    return store
}

/// 讓背景執行中的 Store 有機會處理事件，直到條件成立。
@MainActor
private func waitUntil(_ condition: () -> Bool) async {
    for _ in 0..<10_000 where !condition() {
        await Task.yield()
    }
}

// MARK: - 連線狀態出現在 Store snapshot

@MainActor
struct ConnectionStateSnapshotTests {
    @Test(arguments: [ConnectionState.connected, .disconnected, .reconnecting])
    func everyConnectionStateAppearsInTheSnapshot(state: ConnectionState) async {
        let store = await finishedStore(
            with: [session("a", rawState: "working", paneLabel: "Pane 1")],
            events: [.connectionChanged(.disconnected), .connectionChanged(state)]
        )

        #expect(store.snapshot.connectionState == state)
    }
}

// MARK: - 斷線與重連中

@MainActor
struct DisconnectedPresentationTests {
    @Test(arguments: [ConnectionState.disconnected, .reconnecting])
    func menuBarShowsOnlyTheDisconnectedIconWithoutAnyNumber(state: ConnectionState) async {
        let store = await finishedStore(
            with: [
                session("a", rawState: "working", paneLabel: "Pane 1"),
                session("b", rawState: "needsApproval", paneLabel: "Pane 2"),
                session("c", rawState: "idle", paneLabel: "Pane 3"),
            ],
            events: [.connectionChanged(state)]
        )
        let summary = MenuBarSummary(snapshot: store.snapshot, alwaysShowZero: true, showDoneCount: true)
        let text = MenuBarSummaryFormatter.text(for: summary)

        #expect(summary.mode == .disconnected)
        #expect(summary.items.isEmpty)
        #expect(text == "⚠ 斷線")
        #expect(text.contains { $0.isNumber } == false)
        #expect(MenuBarSummaryFormatter.symbolName(for: summary) == "exclamationmark.triangle")
    }

    @Test func storeKeepsTheLastListButMarksEverySessionStale() async {
        let store = await finishedStore(
            with: [
                session("a", rawState: "working", paneLabel: "Pane 1"),
                session("b", rawState: "needsApproval", paneLabel: "Pane 2"),
            ],
            events: [.connectionChanged(.disconnected)]
        )
        let model = SessionListModel(snapshot: store.snapshot)

        #expect(allRows(model).map(\.id.rawValue) == ["b", "a"])
        #expect(allRows(model).map(\.isStale) == [true, true])
        #expect(allRows(model).map(\.stateText) == ["等核准（過期）", "幹活中（過期）"])
    }

    @Test func footerShowsDisconnectionTheLastSuccessfulUpdateAndAStaleNotice() async {
        let store = await finishedStore(
            with: [session("a", rawState: "working", paneLabel: "Pane 1")],
            events: [.connectionChanged(.disconnected)]
        )
        let footer = SessionListModel(snapshot: store.snapshot).footer

        #expect(footer.connectionText == "已斷線")
        #expect(footer.lastUpdatedAt == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(footer.lastUpdatedText(now: Date(timeIntervalSince1970: 1_800_000_180)) == "最後更新：3 分鐘前")
        #expect(footer.staleNotice == "資料可能已過期，以上清單為最後一次成功更新的內容。")
    }

    @Test func reconnectingFooterAlsoCarriesTheStaleNotice() async {
        let store = await finishedStore(
            with: [session("a", rawState: "working", paneLabel: "Pane 1")],
            events: [.connectionChanged(.reconnecting)]
        )
        let footer = SessionListModel(snapshot: store.snapshot).footer

        #expect(footer.connectionText == "重新連線中")
        #expect(footer.staleNotice == "資料可能已過期，以上清單為最後一次成功更新的內容。")
    }

    @Test func connectedFooterHasNoStaleNotice() async {
        let store = await finishedStore(with: [session("a", rawState: "working", paneLabel: "Pane 1")])

        #expect(SessionListModel(snapshot: store.snapshot).footer.staleNotice == nil)
    }

    @Test func neverConnectedShowsDisconnectedNotZeroAgents() async {
        let adapter = FakeHerdrAdapter()
        await adapter.setSnapshotError(SnapshotUnavailable())
        adapter.finish()
        let store = SessionStore(adapter: adapter, now: { t0 })
        await store.start()
        let model = SessionListModel(snapshot: store.snapshot)

        #expect(menuBarText(store) == "⚠ 斷線")
        #expect(model.emptyStateText == "未連線，沒有可顯示的 Session 資料")
        #expect(model.footer.lastUpdatedText(now: t0) == "尚未成功更新")
        #expect(model.footer.staleNotice == nil)
    }
}

// MARK: - 最後更新時間文字

struct LastUpdatedTextTests {
    private func footer(lastUpdatedAt: Date?) -> SessionListModel.Footer {
        SessionListModel.Footer(
            sourceName: "Herdr",
            connectionState: .disconnected,
            connectionText: "已斷線",
            lastUpdatedAt: lastUpdatedAt
        )
    }

    @Test(arguments: [
        (0.0, "最後更新：剛剛"),
        (9.0, "最後更新：剛剛"),
        (10.0, "最後更新：10 秒前"),
        (59.0, "最後更新：59 秒前"),
        (60.0, "最後更新：1 分鐘前"),
        (3_599.0, "最後更新：59 分鐘前"),
        (3_600.0, "最後更新：1 小時前"),
        (86_399.0, "最後更新：23 小時前"),
        (86_400.0, "最後更新：1 天前"),
        (-30.0, "最後更新：剛剛"),
    ])
    func relativeTextFromTheInjectedNow(elapsed: TimeInterval, expected: String) {
        let updatedAt = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(footer(lastUpdatedAt: updatedAt).lastUpdatedText(now: updatedAt.addingTimeInterval(elapsed)) == expected)
    }

    @Test func neverUpdatedSaysSo() {
        #expect(footer(lastUpdatedAt: nil).lastUpdatedText(now: t0) == "尚未成功更新")
    }
}

// MARK: - 重連後恢復

@MainActor
struct ReconnectionTests {
    @Test func summaryAndListReturnToNormalAfterReconnecting() async {
        let store = await finishedStore(
            with: [
                session("a", rawState: "working", paneLabel: "Pane 1"),
                session("b", rawState: "idle", paneLabel: "Pane 2"),
            ],
            events: [.connectionChanged(.disconnected), .connectionChanged(.reconnecting), .connectionChanged(.connected)]
        )
        let model = SessionListModel(snapshot: store.snapshot)

        #expect(menuBarText(store) == "⚒ 1  💤 1")
        #expect(MenuBarSummaryFormatter.symbolName(for: MenuBarSummary(snapshot: store.snapshot)) == nil)
        #expect(allRows(model).map(\.stateText) == ["幹活中", "閒置"])
        #expect(allRows(model).map(\.isStale) == [false, false])
        #expect(model.footer.connectionText == "已連線")
        #expect(model.footer.staleNotice == nil)
    }

    @Test func storeReadsTheSnapshotAgainAfterReconnecting() async {
        let clock = TestClock(t0)
        let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: [
            session("a", rawState: "working", paneLabel: "Pane 1"),
            session("b", rawState: "idle", paneLabel: "Pane 2"),
        ]))
        let store = SessionStore(adapter: adapter, now: { clock.now() })
        let running = Task { await store.start() }

        adapter.send(.connectionChanged(.disconnected))
        await waitUntil { store.snapshot.connectionState == .disconnected && !store.snapshot.sessions.isEmpty }
        #expect(menuBarText(store) == "⚠ 斷線")

        // 斷線期間 a 完成、b 被關閉、c 開始等核准。
        let reconnectedAt = Date(timeIntervalSince1970: 1_800_000_300)
        await adapter.setSnapshot(SessionSnapshot(sessions: [
            session("a", rawState: "done", paneLabel: "Pane 1", updatedAt: reconnectedAt),
            session("c", rawState: "needsApproval", paneLabel: "Pane 3", updatedAt: reconnectedAt),
        ]))
        clock.set(reconnectedAt)
        adapter.send(.connectionChanged(.connected))
        adapter.finish()
        await running.value

        let model = SessionListModel(snapshot: store.snapshot)
        #expect(store.snapshot.connectionState == .connected)
        #expect(store.snapshot.lastUpdatedAt == Date(timeIntervalSince1970: 1_800_000_300))
        #expect(allRows(model).map(\.id.rawValue) == ["c", "a"])
        #expect(allRows(model).map(\.stateText) == ["等核准", "完成"])
        #expect(menuBarText(store) == "✋ 1 •")
    }

    @Test func failedSnapshotAfterReconnectKeepsTheDisconnectedPresentation() async {
        let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: [
            session("a", rawState: "working", paneLabel: "Pane 1"),
        ]))
        let store = SessionStore(adapter: adapter, now: { t0 })
        let running = Task { await store.start() }

        adapter.send(.connectionChanged(.disconnected))
        await waitUntil { store.snapshot.connectionState == .disconnected && !store.snapshot.sessions.isEmpty }

        await adapter.setSnapshotError(SnapshotUnavailable())
        adapter.send(.connectionChanged(.connected))
        adapter.finish()
        await running.value

        let model = SessionListModel(snapshot: store.snapshot)
        #expect(store.snapshot.connectionState == .disconnected)
        #expect(menuBarText(store) == "⚠ 斷線")
        #expect(allRows(model).map(\.stateText) == ["幹活中（過期）"])
        #expect(model.footer.lastUpdatedAt == Date(timeIntervalSince1970: 1_800_000_000))
    }

    @Test func connectingAfterAFailedStartLoadsTheSnapshot() async {
        let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: [
            session("a", rawState: "working", paneLabel: "Pane 1"),
        ]))
        await adapter.setSnapshotError(SnapshotUnavailable())
        let store = SessionStore(adapter: adapter, now: { t0 })
        let running = Task { await store.start() }

        // 初始狀態本來就是 disconnected；先等 Store 處理完一個重連中事件，確保啟動時的快照讀取已經失敗過。
        adapter.send(.connectionChanged(.reconnecting))
        await waitUntil { store.snapshot.connectionState == .reconnecting }
        #expect(menuBarText(store) == "⚠ 斷線")
        await adapter.setSnapshotError(nil)
        adapter.send(.connectionChanged(.connected))
        adapter.finish()
        await running.value

        #expect(store.snapshot.connectionState == .connected)
        #expect(menuBarText(store) == "⚒ 1")
    }
}

// MARK: - 零 Agent

@MainActor
struct ZeroAgentsTests {
    @Test func connectedWithNoSessionsShowsAnExplicitZeroState() async {
        let store = await finishedStore(with: [])
        let summary = MenuBarSummary(snapshot: store.snapshot)
        let model = SessionListModel(snapshot: store.snapshot)

        #expect(summary.mode == .zeroAgents)
        #expect(MenuBarSummaryFormatter.text(for: summary) == "0 個 Agent")
        #expect(MenuBarSummaryFormatter.symbolName(for: summary) == nil)
        #expect(model.agentCount == 0)
        #expect(model.emptyStateText == "目前沒有 Agent Session")
        #expect(model.footer.connectionText == "已連線")
        #expect(model.footer.staleNotice == nil)
    }

    @Test func zeroAgentsDiffersFromDisconnectedWithNoSessions() async {
        let zero = await finishedStore(with: [])
        let disconnected = await finishedStore(with: [], events: [.connectionChanged(.disconnected)])
        let zeroModel = SessionListModel(snapshot: zero.snapshot)
        let disconnectedModel = SessionListModel(snapshot: disconnected.snapshot)

        #expect(menuBarText(zero) == "0 個 Agent")
        #expect(menuBarText(disconnected) == "⚠ 斷線")
        #expect(zeroModel.emptyStateText == "目前沒有 Agent Session")
        #expect(disconnectedModel.emptyStateText == "未連線，沒有可顯示的 Session 資料")
    }

    @Test func removingTheLastSessionSwitchesToTheZeroState() async {
        let store = await finishedStore(
            with: [session("a", rawState: "working", paneLabel: "Pane 1")],
            events: [.sessionRemoved(AgentSessionID("a"))]
        )

        #expect(menuBarText(store) == "0 個 Agent")
        #expect(SessionListModel(snapshot: store.snapshot).emptyStateText == "目前沒有 Agent Session")
    }

    @Test func listWithSessionsHasNoEmptyStateText() async {
        let store = await finishedStore(with: [session("a", rawState: "working", paneLabel: "Pane 1")])

        #expect(SessionListModel(snapshot: store.snapshot).emptyStateText == nil)
    }
}
