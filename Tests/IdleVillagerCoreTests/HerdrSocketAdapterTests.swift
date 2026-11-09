import Foundation
import Testing
@testable import IdleVillagerCore

/// 真實 Herdr socket 不進自動化測試；這裡以固定 JSON 樣本測試解碼、對應、對帳與訂閱集合等純邏輯。
///
/// Fixtures are read from the source tree instead of `Bundle.module`: IdleVillagerCore now has resources too, so with
/// `@testable import` its internal `Bundle.module` is visible here and could make the test target's own accessor ambiguous.
private func fixtureData(_ name: String) throws -> Data {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/\(name).json")
    return try Data(contentsOf: url)
}

private func decodeSnapshot(_ data: Data) throws -> HerdrWire.Snapshot {
    let response = try HerdrWire.decode(HerdrWire.Response<HerdrWire.SnapshotResult>.self, from: data)
    return try #require(response.result).snapshot
}

private let receivedAt = Date(timeIntervalSince1970: 1_800_000_000)

/// 手寫的小快照：一個 blocked、一個沒有標題的 Agent，加上一個沒有 Agent 的 Pane。
private let smallSnapshotJSON = """
{"id":"x","result":{"type":"session_snapshot","snapshot":{
  "version":"0.9.5","protocol":22,"focused_pane_id":"w1:p2","focused_tab_id":"w1:t1","focused_workspace_id":"w1",
  "layouts":[],
  "workspaces":[{"workspace_id":"w1","label":"Main","number":1,"agent_status":"blocked","focused":true}],
  "tabs":[{"tab_id":"w1:t1","workspace_id":"w1","label":"API","number":1,"focused":true},
          {"tab_id":"w1:t2","workspace_id":"w1","label":"  ","number":2,"focused":false}],
  "panes":[{"pane_id":"w1:p1","terminal_id":"term_a","workspace_id":"w1","tab_id":"w1:t1","focused":false,"agent_status":"blocked","revision":1,"agent":"claude"},
           {"pane_id":"w1:p2","terminal_id":"term_b","workspace_id":"w1","tab_id":"w1:t2","focused":true,"agent_status":"idle","revision":1,"agent":"codex","label":"Reviewer"},
           {"pane_id":"w1:p3","terminal_id":"term_c","workspace_id":"w1","tab_id":"w1:t2","focused":false,"agent_status":"unknown","revision":1}],
  "agents":[{"terminal_id":"term_a","pane_id":"w1:p1","tab_id":"w1:t1","workspace_id":"w1","agent":"claude","agent_status":"blocked",
             "focused":false,"revision":1,"cwd":"/secret/path","terminal_title":"* Fix login","terminal_title_stripped":"Fix login"},
            {"terminal_id":"term_b","pane_id":"w1:p2","tab_id":"w1:t2","workspace_id":"w1","agent":"codex","agent_status":"idle",
             "focused":true,"revision":1,"terminal_title_stripped":""}]
}}}
"""

struct HerdrSnapshotMappingTests {
    @Test func capturedSnapshotDecodesAndOnlyAgentsBecomeSessions() throws {
        let snapshot = try decodeSnapshot(try fixtureData("herdr-snapshot"))
        let sessions = HerdrSnapshotMapper.sessions(from: snapshot, receivedAt: receivedAt)

        #expect(snapshot.panes.count == 15)
        #expect(sessions.count == snapshot.agents.count)
        #expect(sessions.count == 5)
        #expect(sessions.map(\.agentSessionID.rawValue) == snapshot.agents.map(\.terminalID))
        #expect(Set(sessions.map(\.agentSessionID)).count == sessions.count)
        #expect(sessions.allSatisfy { $0.stateSource == .explicitEvent && $0.updatedAt == receivedAt && $0.waitingReason == nil })
        #expect(sessions.allSatisfy { $0.agentKind == "claude" })
        #expect(sessions.map(\.rawState) == ["idle", "idle", "idle", "done", "working"])
    }

    @Test func capturedSnapshotUsesWorkspaceAndTabLabels() throws {
        let snapshot = try decodeSnapshot(try fixtureData("herdr-snapshot"))
        let session = try #require(HerdrSnapshotMapper.sessions(from: snapshot, receivedAt: receivedAt).first)

        #expect(session.workspaceID == WorkspaceID("w1"))
        #expect(session.workspaceName == "Workspace 1")
        #expect(session.tabID == TabID("w1:t1"))
        #expect(session.tabName == "Tab 1")
        #expect(session.paneID == PaneID("w1:p1"))
        #expect(session.paneLabel == "w1:p1")
    }

    @Test func mapsEveryFieldPerTheVerifiedRules() throws {
        let snapshot = try decodeSnapshot(Data(smallSnapshotJSON.utf8))
        let sessions = HerdrSnapshotMapper.sessions(from: snapshot, receivedAt: receivedAt)

        #expect(sessions == [
            AgentSession(
                workspaceID: WorkspaceID("w1"), workspaceName: "Main",
                tabID: TabID("w1:t1"), tabName: "API",
                paneID: PaneID("w1:p1"), paneLabel: "w1:p1",
                agentSessionID: AgentSessionID("term_a"), agentKind: "claude", displayName: "Fix login",
                rawState: "blocked", updatedAt: receivedAt, stateSource: .explicitEvent
            ),
            // 空白的 Tab 名稱退回 Tab ID；沒有標題時顯示名稱退回 Agent 種類；Pane 有 label 時用 label。
            AgentSession(
                workspaceID: WorkspaceID("w1"), workspaceName: "Main",
                tabID: TabID("w1:t2"), tabName: "w1:t2",
                paneID: PaneID("w1:p2"), paneLabel: "Reviewer",
                agentSessionID: AgentSessionID("term_b"), agentKind: "codex", displayName: "codex",
                rawState: "idle", updatedAt: receivedAt, stateSource: .explicitEvent
            ),
        ])
    }

    @Test func mappedSessionsNormalizeThroughTheStateTable() throws {
        let snapshot = try decodeSnapshot(Data(smallSnapshotJSON.utf8))
        let states = HerdrSnapshotMapper.sessions(from: snapshot, receivedAt: receivedAt).map { StateNormalizer.normalize($0).state }

        #expect(states == [.needsApproval, .idle])
    }

    @Test func errorResponseDecodesTheCode() throws {
        let line = Data(#"{"id":"x","error":{"code":"agent_not_found","message":"agent target w9:p9 not found"}}"#.utf8)
        let response = try HerdrWire.decode(HerdrWire.Response<HerdrWire.AgentResult>.self, from: line)

        #expect(response.result == nil)
        #expect(response.error?.code == HerdrWire.RPCError.agentNotFound)
    }

    @Test func agentInfoResultDecodesFocusedFlag() throws {
        let line = Data(#"""
        {"id":"x","result":{"type":"agent_info","agent":{"terminal_id":"term_a","agent":"claude","agent_status":"working",
         "workspace_id":"w2","tab_id":"w2:t1","pane_id":"w2:p1","focused":true,"revision":12}}}
        """#.utf8)
        let agent = try #require(try HerdrWire.decode(HerdrWire.Response<HerdrWire.AgentResult>.self, from: line).result).agent

        #expect(agent.terminalID == "term_a")
        #expect(agent.focused == true)
    }

    @Test func requestLineIsOneJSONObjectWithIDMethodAndParams() throws {
        let line = try HerdrWire.requestLine(id: "r1", method: .sessionSnapshot)

        #expect(line.last == 0x0A)
        #expect(line.dropLast().contains(0x0A) == false)
        let object = try #require(try JSONSerialization.jsonObject(with: line) as? [String: Any])
        #expect(object["id"] as? String == "r1")
        #expect(object["method"] as? String == "session.snapshot")
        #expect((object["params"] as? [String: Any])?.isEmpty == true)
    }
}

struct HerdrEventTests {
    @Test func statusChangedEnvelopeDecodes() throws {
        let line = Data(#"{"data":{"agent":"claude","agent_status":"idle","pane_id":"w2:p1","workspace_id":"w2"},"event":"pane.agent_status_changed"}"#.utf8)
        let envelope = try HerdrWire.decode(HerdrWire.EventEnvelope.self, from: line)

        #expect(envelope.event == "pane.agent_status_changed")
        #expect(envelope.normalizedKind == "pane_agent_status_changed")
        #expect(envelope.data == HerdrWire.EventData(paneID: "w2:p1", workspaceID: "w2", agent: "claude", agentStatus: "idle"))
        #expect(HerdrEventAction.classify(envelope, knownAgentPanes: [PaneID("w2:p1")]) == .stateChanged(paneID: PaneID("w2:p1"), rawState: "idle"))
    }

    @Test func statusChangeForAnUnknownPaneOrVanishedAgentTriggersAResnapshot() throws {
        let unknownPane = try HerdrWire.decode(HerdrWire.EventEnvelope.self, from: Data(
            #"{"data":{"agent":"claude","agent_status":"working","pane_id":"w9:p1","workspace_id":"w9"},"event":"pane.agent_status_changed"}"#.utf8
        ))
        let vanished = try HerdrWire.decode(HerdrWire.EventEnvelope.self, from: Data(
            #"{"data":{"agent":null,"agent_status":"unknown","pane_id":"w2:p1","workspace_id":"w2"},"event":"pane.agent_status_changed"}"#.utf8
        ))

        #expect(HerdrEventAction.classify(unknownPane, knownAgentPanes: [PaneID("w2:p1")]) == .resnapshot)
        #expect(HerdrEventAction.classify(vanished, knownAgentPanes: [PaneID("w2:p1")]) == .resnapshot)
    }

    @Test(arguments: ["pane_created", "pane_closed", "pane_updated", "pane_moved", "pane_exited", "pane_agent_detected",
                      "tab_created", "tab_closed", "tab_renamed", "workspace_closed", "workspace_renamed"])
    func lifecycleEventsTriggerAResnapshot(kind: String) throws {
        let line = Data(#"{"data":{"pane_id":"w1:p1","type":"\#(kind)","workspace_id":"w1"},"event":"\#(kind)"}"#.utf8)
        let envelope = try HerdrWire.decode(HerdrWire.EventEnvelope.self, from: line)

        #expect(HerdrEventAction.classify(envelope, knownAgentPanes: []) == .resnapshot)
    }

    @Test(arguments: ["pane_focused", "tab_focused", "workspace_focused", "layout_updated"])
    func focusEventsAreIgnored(kind: String) throws {
        let line = Data(#"{"data":{"type":"\#(kind)","workspace_id":"w1"},"event":"\#(kind)"}"#.utf8)
        let envelope = try HerdrWire.decode(HerdrWire.EventEnvelope.self, from: line)

        #expect(HerdrEventAction.classify(envelope, knownAgentPanes: []) == .ignore)
    }
}

private func session(_ id: String, pane: String, rawState: String = "idle", title: String = "Task", at time: Date = receivedAt) -> AgentSession {
    AgentSession(
        workspaceID: WorkspaceID("w1"), workspaceName: "Main",
        tabID: TabID("w1:t1"), tabName: "Tab",
        paneID: PaneID(pane), paneLabel: pane,
        agentSessionID: AgentSessionID(id), agentKind: "claude", displayName: title,
        rawState: rawState, updatedAt: time, stateSource: .explicitEvent
    )
}

struct HerdrSnapshotDiffTests {
    @Test func addedAndRemovedSessionsBecomeAddedAndRemovedEvents() {
        let later = receivedAt.addingTimeInterval(30)
        let old = [session("a", pane: "w1:p1"), session("b", pane: "w1:p2")]
        let new = [session("b", pane: "w1:p2", at: later), session("c", pane: "w1:p3", at: later)]

        #expect(HerdrSnapshotDiff.events(from: old, to: new) == [
            .sessionRemoved(AgentSessionID("a")),
            .sessionStateChanged(AgentSessionID("b"), rawState: "idle", stateSource: .explicitEvent, updatedAt: later),
            .sessionAdded(session("c", pane: "w1:p3", at: later)),
        ])
    }

    @Test func unchangedSessionStillGetsAStateEventSoItIsNotStale() {
        let later = receivedAt.addingTimeInterval(30)
        let events = HerdrSnapshotDiff.events(from: [session("a", pane: "w1:p1")], to: [session("a", pane: "w1:p1", at: later)])

        #expect(events == [.sessionStateChanged(AgentSessionID("a"), rawState: "idle", stateSource: .explicitEvent, updatedAt: later)])
    }

    @Test func stateChangeIsReportedAsAStateEvent() {
        let events = HerdrSnapshotDiff.events(from: [session("a", pane: "w1:p1")], to: [session("a", pane: "w1:p1", rawState: "blocked")])

        #expect(events == [.sessionStateChanged(AgentSessionID("a"), rawState: "blocked", stateSource: .explicitEvent, updatedAt: receivedAt)])
    }

    @Test func metadataChangeReplacesTheWholeSession() {
        let moved = session("a", pane: "w2:p1", title: "Renamed")
        let events = HerdrSnapshotDiff.events(from: [session("a", pane: "w1:p1")], to: [moved])

        #expect(events == [.sessionAdded(moved)])
    }

    @Test func emptyToEmptyHasNoEvents() {
        #expect(HerdrSnapshotDiff.events(from: [], to: []).isEmpty)
    }

    @MainActor
    @Test func storeAppliesTheDiffToMatchTheNewSnapshot() async {
        let old = [session("a", pane: "w1:p1"), session("b", pane: "w1:p2", rawState: "working")]
        let new = [session("b", pane: "w1:p2", rawState: "blocked"), session("c", pane: "w1:p3", rawState: "done")]
        let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: old))
        for event in HerdrSnapshotDiff.events(from: old, to: new) { adapter.send(event) }
        adapter.finish()
        let store = SessionStore(adapter: adapter, now: { receivedAt })
        await store.start()

        #expect(Set(store.snapshot.sessions.map(\.session)) == Set(new))
        #expect(store.snapshot.counts.needsApproval == 1)
        #expect(store.snapshot.counts.done == 1)
    }
}

struct HerdrSubscriptionPlanTests {
    @Test func subscribesToEveryLifecycleTypePlusOneStatusSubscriptionPerAgentPane() {
        let plan = HerdrSubscriptionPlan.subscriptions(agentPaneIDs: [PaneID("w2:p1"), PaneID("w1:p3")])

        #expect(plan.count == HerdrSubscriptionPlan.lifecycleTypes.count + 2)
        #expect(Array(plan.suffix(2)) == [
            .init(type: "pane.agent_status_changed", paneID: PaneID("w1:p3")),
            .init(type: "pane.agent_status_changed", paneID: PaneID("w2:p1")),
        ])
        #expect(plan.suffix(1).first?.jsonObject == ["type": "pane.agent_status_changed", "pane_id": "w2:p1"])
        #expect(plan.first?.jsonObject == ["type": "workspace.created"])
    }

    @Test func neverSubscribesToEventsCarryingTerminalContent() {
        let types = Set(HerdrSubscriptionPlan.subscriptions(agentPaneIDs: [PaneID("w1:p1")]).map(\.type))

        #expect(!types.contains("pane.output_matched"))
        #expect(!types.contains("pane.scroll_changed"))
        #expect(types.isSuperset(of: ["pane.created", "pane.closed", "pane.updated", "pane.moved", "pane.exited", "pane.agent_detected",
                                      "tab.created", "tab.closed", "workspace.created", "workspace.closed"]))
    }

    @Test func agentPaneSetComesFromTheMappedSessions() throws {
        let snapshot = try decodeSnapshot(try fixtureData("herdr-snapshot"))
        let panes = HerdrSnapshotMapper.agentPaneIDs(in: HerdrSnapshotMapper.sessions(from: snapshot, receivedAt: receivedAt))

        #expect(panes == Set(["w1:p1", "w1:p3", "w1:p6", "w2:p1", "w5:p1"].map(PaneID.init)))
    }
}

struct HerdrBackoffTests {
    @Test func backoffDoublesFromOneSecondAndCapsAtThirty() {
        var backoff = HerdrBackoff()
        let delays = (0..<8).map { _ in backoff.next() }

        #expect(delays == [1, 2, 4, 8, 16, 30, 30, 30])
    }

    @Test func resetStartsAgainFromOneSecond() {
        var backoff = HerdrBackoff()
        _ = backoff.next()
        _ = backoff.next()
        backoff.reset()

        #expect(backoff.next() == 1)
    }
}

struct HerdrClientProcessLocatorTests {
    @Test(arguments: [
        (["herdr"], true),
        (["/Users/example/.local/bin/herdr", "--session", "work"], true),
        (["/Users/example/.local/bin/herdr", "server"], false),
    ])
    func serverProcessIsNotAClient(arguments: [String], expected: Bool) {
        #expect(HerdrClientProcessLocator.isClient(arguments: arguments) == expected)
    }

    @Test func ancestryOfThisProcessStartsWithItselfAndEndsAtLaunchd() {
        let chain = HerdrClientProcessLocator.ancestry(of: getpid())

        #expect(chain.first == getpid())
        #expect(chain.last == 1)
    }
}

struct HerdrSocketAdapterTests {
    @Test func reportsTheVerifiedHerdrSourceName() {
        let adapter = HerdrSocketAdapter(socketPath: "/nonexistent/herdr.sock", activator: NeverActivator())

        #expect(adapter.sourceDescription == SourceDescription.herdr)
    }

    @Test func missingSocketThrowsUnreachableAndFocusReportsDisconnected() async {
        let adapter = HerdrSocketAdapter(socketPath: "/nonexistent/herdr.sock", activator: NeverActivator())

        await #expect(throws: HerdrTransportError.unreachable) { try await adapter.snapshot() }
        #expect(await adapter.focus(sessionID: AgentSessionID("term_a"), paneID: PaneID("w1:p1")) == .failure(.disconnected))
        await adapter.stop()
    }
}

private struct NeverActivator: TerminalActivator {
    func activate(processAncestries: [[pid_t]]) async -> Bool { false }
}
