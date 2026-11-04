import Foundation
import Testing
import IdleVillagerCore

private func session(
    _ id: String,
    rawState: String,
    workspace: (id: String, name: String),
    tab: (id: String, name: String),
    paneLabel: String
) -> AgentSession {
    AgentSession(
        workspaceID: WorkspaceID(workspace.id),
        workspaceName: workspace.name,
        tabID: TabID(tab.id),
        tabName: tab.name,
        paneID: PaneID("pane-\(id)"),
        paneLabel: paneLabel,
        agentSessionID: AgentSessionID(id),
        agentKind: "claude",
        displayName: "Claude Code",
        rawState: rawState,
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        stateSource: .explicitEvent
    )
}

private func stateChanged(_ id: String, to rawState: String) -> AdapterEvent {
    .sessionStateChanged(AgentSessionID(id), rawState: rawState, stateSource: .explicitEvent,
                         updatedAt: Date(timeIntervalSince1970: 1_700_000_100))
}

/// 以 Fake Adapter 餵入 Session 與事件，回傳 Store 處理完後的 snapshot。
@MainActor
private func snapshot(of sessions: [AgentSession], events: [AdapterEvent] = []) async -> StoreSnapshot {
    let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: sessions))
    for event in events { adapter.send(event) }
    adapter.finish()
    let store = SessionStore(adapter: adapter, now: { Date(timeIntervalSince1970: 1_800_000_000) })
    await store.start()
    return store.snapshot
}

/// 三個 Workspace，狀態、名稱與 ID 的順序刻意交錯，讓三種排序規則的輸出都不同。
///
/// ID 的字串順序是 Zeta、Alpha、Beta 9；名稱順序是 Alpha、Beta 9、Zeta；
/// 急件（Needs Approval）在 Beta 9 與 Zeta，Alpha 只有 Working 與 Idle。
private let mixedSessions: [AgentSession] = [
    session("s1", rawState: "idle", workspace: ("ws-a", "Zeta"), tab: ("tab-a1", "Tab 10"), paneLabel: "Pane 1"),
    session("s2", rawState: "needsApproval", workspace: ("ws-a", "Zeta"), tab: ("tab-a2", "Tab 2"), paneLabel: "Pane 1"),
    session("s3", rawState: "idle", workspace: ("ws-b", "Alpha"), tab: ("tab-b1", "Main"), paneLabel: "Pane 1"),
    session("s4", rawState: "working", workspace: ("ws-b", "Alpha"), tab: ("tab-b1", "Main"), paneLabel: "Pane 2"),
    session("s5", rawState: "working", workspace: ("ws-c", "Beta 9"), tab: ("tab-c1", "Only"), paneLabel: "Pane 1"),
    session("s6", rawState: "needsApproval", workspace: ("ws-c", "Beta 9"), tab: ("tab-c1", "Only"), paneLabel: "Pane 9"),
    session("s0", rawState: "working", workspace: ("ws-c", "Beta 9"), tab: ("tab-c1", "Only"), paneLabel: "Pane 3"),
]

/// 清單的扁平輸出：Workspace 名稱、Tab 名稱與列 ID，依畫面順序排列。
private func outline(_ model: SessionListModel) -> [String] {
    model.workspaces.flatMap { workspace in
        [workspace.name] + workspace.tabs.flatMap { tab in
            ["  " + tab.name] + tab.rows.map { "    " + $0.id.rawValue }
        }
    }
}

@MainActor
struct SortRuleTests {
    @Test func priorityFloatsUrgentGroupsAndRowsToTheTop() async {
        let model = SessionListModel(snapshot: await snapshot(of: mixedSessions), sortRule: .priority)

        #expect(outline(model) == [
            "Beta 9", "  Only", "    s6", "    s5", "    s0",
            "Zeta", "  Tab 2", "    s2", "  Tab 10", "    s1",
            "Alpha", "  Main", "    s4", "    s3",
        ])
    }

    @Test func defaultInitializerUsesPriority() async {
        let snapshot = await snapshot(of: mixedSessions)

        #expect(SessionListModel(snapshot: snapshot) == SessionListModel(snapshot: snapshot, sortRule: .priority))
    }

    @Test func workspaceNameSortsGroupsByNameButRowsByPriority() async {
        let model = SessionListModel(snapshot: await snapshot(of: mixedSessions), sortRule: .workspaceName)

        #expect(outline(model) == [
            "Alpha", "  Main", "    s4", "    s3",
            "Beta 9", "  Only", "    s6", "    s5", "    s0",
            "Zeta", "  Tab 2", "    s2", "  Tab 10", "    s1",
        ])
    }

    @Test func fixedSortsEverythingByStableID() async {
        let model = SessionListModel(snapshot: await snapshot(of: mixedSessions), sortRule: .fixed)

        #expect(outline(model) == [
            "Zeta", "  Tab 10", "    s1", "  Tab 2", "    s2",
            "Alpha", "  Main", "    s3", "    s4",
            "Beta 9", "  Only", "    s0", "    s5", "    s6",
        ])
    }

    @Test func fixedOrderDoesNotMoveWhenStatesChange() async {
        let changed = await snapshot(of: mixedSessions, events: [
            stateChanged("s1", to: "needsApproval"),
            stateChanged("s2", to: "idle"),
            stateChanged("s3", to: "needsApproval"),
        ])

        #expect(outline(SessionListModel(snapshot: changed, sortRule: .fixed)) == [
            "Zeta", "  Tab 10", "    s1", "  Tab 2", "    s2",
            "Alpha", "  Main", "    s3", "    s4",
            "Beta 9", "  Only", "    s0", "    s5", "    s6",
        ])
        #expect(outline(SessionListModel(snapshot: changed, sortRule: .priority)) == [
            "Alpha", "  Main", "    s3", "    s4",
            "Beta 9", "  Only", "    s6", "    s5", "    s0",
            "Zeta", "  Tab 10", "    s1", "  Tab 2", "    s2",
        ])
    }

    @Test func listFollowsTheSettingImmediately() async {
        let snapshot = await snapshot(of: mixedSessions)
        let settings = AppSettings(store: InMemorySettingsStore())

        #expect(outline(SessionListModel(snapshot: snapshot, settings: settings)).first == "Beta 9")

        settings.sortRule = .fixed
        #expect(outline(SessionListModel(snapshot: snapshot, settings: settings)).first == "Zeta")

        settings.sortRule = .workspaceName
        #expect(outline(SessionListModel(snapshot: snapshot, settings: settings)).first == "Alpha")
    }
}

@MainActor
struct AnimationSettingTests {
    /// 從設定與清單列一路推到角色動作，模擬 Popover 列的繪製流程。
    private func motion(for state: NormalizedState, previous: NormalizedState?, settings: AppSettings) -> CharacterMotion {
        let presentation = CharacterPresentation(state: state, previousState: previous, reduceMotion: false)
        return CharacterMotion(pose: presentation.pose, transition: presentation.transition,
                               reduceMotion: false, animationsEnabled: settings.animationsEnabled)
    }

    @Test func turningAnimationsOffLeavesOnlyStaticPoses() async {
        let snapshot = await snapshot(of: [
            session("s1", rawState: "working", workspace: ("ws-1", "W"), tab: ("tab-1", "T"), paneLabel: "Pane 1"),
        ])
        let row = SessionListModel(snapshot: snapshot).workspaces[0].tabs[0].rows[0]
        let settings = AppSettings(store: InMemorySettingsStore())

        #expect(motion(for: row.state, previous: nil, settings: settings).loop == .workingBob)
        #expect(motion(for: .done, previous: row.state, settings: settings).transition == .celebrateOnce)

        settings.animationsEnabled = false

        // 效果等同系統 Reduce Motion。
        #expect(motion(for: row.state, previous: nil, settings: settings)
                == CharacterMotion(pose: .working, transition: nil, reduceMotion: true, animationsEnabled: true))
        #expect(motion(for: row.state, previous: nil, settings: settings).loop == nil)
        #expect(motion(for: .done, previous: row.state, settings: settings).transition == nil)
        #expect(motion(for: .idle, previous: .working, settings: settings).transition == nil)
        #expect(motion(for: .needsApproval, previous: nil, settings: settings).loop == nil)
    }
}

@MainActor
struct ApprovalAlertTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private var idleSession: AgentSession {
        session("s1", rawState: "idle", workspace: ("ws-1", "W"), tab: ("tab-1", "T"), paneLabel: "Pane 1")
    }

    @Test func countRisingFromZeroToOneAlertsForThreeSeconds() async {
        let before = await snapshot(of: [idleSession])
        let after = await snapshot(of: [idleSession], events: [stateChanged("s1", to: "needsApproval")])
        let settings = AppSettings(store: InMemorySettingsStore())
        var tracker = ApprovalAlertTracker()

        tracker.observe(needsApprovalCount: before.counts.needsApproval, settings: settings, now: t0)
        #expect(tracker.alertUntil == nil)

        tracker.observe(needsApprovalCount: after.counts.needsApproval, settings: settings, now: t0)
        #expect(tracker.alertUntil == Date(timeIntervalSince1970: 1_800_000_003))
        #expect(tracker.isAlerting(at: Date(timeIntervalSince1970: 1_800_000_002.5)))
        #expect(tracker.isAlerting(at: Date(timeIntervalSince1970: 1_800_000_003)) == false)
    }

    @Test func countFallingFromOneToZeroDoesNotAlert() async {
        let withApproval = await snapshot(of: [idleSession], events: [stateChanged("s1", to: "needsApproval")])
        let resolved = await snapshot(of: [idleSession])
        let settings = AppSettings(store: InMemorySettingsStore())
        var tracker = ApprovalAlertTracker()

        tracker.observe(needsApprovalCount: withApproval.counts.needsApproval, settings: settings, now: t0)
        tracker.observe(needsApprovalCount: resolved.counts.needsApproval, settings: settings, now: t0)

        #expect(tracker.alertUntil == nil)
        #expect(tracker.isAlerting(at: t0) == false)
    }

    @Test func unchangedCountDoesNotAlertAgain() {
        let settings = AppSettings(store: InMemorySettingsStore())
        var tracker = ApprovalAlertTracker()

        tracker.observe(needsApprovalCount: 0, settings: settings, now: t0)
        tracker.observe(needsApprovalCount: 2, settings: settings, now: t0)
        tracker.observe(needsApprovalCount: 2, settings: settings, now: Date(timeIntervalSince1970: 1_800_000_010))

        #expect(tracker.alertUntil == Date(timeIntervalSince1970: 1_800_000_003))
        #expect(tracker.isAlerting(at: Date(timeIntervalSince1970: 1_800_000_010)) == false)
    }

    @Test func firstObservationOnlySetsTheBaseline() {
        let settings = AppSettings(store: InMemorySettingsStore())
        var tracker = ApprovalAlertTracker()

        tracker.observe(needsApprovalCount: 3, settings: settings, now: t0)

        #expect(tracker.alertUntil == nil)
    }

    @Test func switchedOffNeverAlerts() async {
        let before = await snapshot(of: [idleSession])
        let after = await snapshot(of: [idleSession], events: [stateChanged("s1", to: "needsApproval")])
        let settings = AppSettings(store: InMemorySettingsStore())
        settings.lowDistractionAlerts = false
        var tracker = ApprovalAlertTracker()

        tracker.observe(needsApprovalCount: before.counts.needsApproval, settings: settings, now: t0)
        tracker.observe(needsApprovalCount: after.counts.needsApproval, settings: settings, now: t0)

        #expect(tracker.alertUntil == nil)
        #expect(tracker.isAlerting(at: t0) == false)
    }

    @Test func switchingOffClearsARunningAlert() {
        let settings = AppSettings(store: InMemorySettingsStore())
        var tracker = ApprovalAlertTracker()
        tracker.observe(needsApprovalCount: 0, settings: settings, now: t0)
        tracker.observe(needsApprovalCount: 1, settings: settings, now: t0)

        settings.lowDistractionAlerts = false
        tracker.observe(needsApprovalCount: 1, settings: settings, now: Date(timeIntervalSince1970: 1_800_000_001))

        #expect(tracker.alertUntil == nil)
    }

    @Test func pureRuleComparesTwoCounts() {
        #expect(ApprovalAlertTracker.alertUntil(previousCount: 0, currentCount: 1, enabled: true, now: t0)
                == Date(timeIntervalSince1970: 1_800_000_003))
        #expect(ApprovalAlertTracker.alertUntil(previousCount: 1, currentCount: 0, enabled: true, now: t0) == nil)
        #expect(ApprovalAlertTracker.alertUntil(previousCount: 1, currentCount: 1, enabled: true, now: t0) == nil)
        #expect(ApprovalAlertTracker.alertUntil(previousCount: 0, currentCount: 1, enabled: false, now: t0) == nil)
    }
}

@MainActor
struct BehaviorSettingsPersistenceTests {
    @Test func behaviorSettingsSurviveARestart() {
        let store = InMemorySettingsStore()
        let beforeRestart = AppSettings(store: store)
        beforeRestart.sortRule = .fixed
        beforeRestart.animationsEnabled = false
        beforeRestart.lowDistractionAlerts = false

        let afterRestart = AppSettings(store: store)

        #expect(afterRestart.sortRule == .fixed)
        #expect(afterRestart.animationsEnabled == false)
        #expect(afterRestart.lowDistractionAlerts == false)
    }
}
