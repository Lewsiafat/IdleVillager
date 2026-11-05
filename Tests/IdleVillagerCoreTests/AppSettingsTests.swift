import Foundation
import Observation
import os
import Testing
import IdleVillagerCore

private func session(_ id: String, rawState: String) -> AgentSession {
    AgentSession(
        workspaceID: WorkspaceID("ws-1"),
        workspaceName: "Backend Project",
        tabID: TabID("tab-1"),
        tabName: "API 開發",
        paneID: PaneID("pane-\(id)"),
        paneLabel: "Pane 1",
        agentSessionID: AgentSessionID(id),
        agentKind: "claude",
        displayName: "Claude Code",
        rawState: rawState,
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        stateSource: .explicitEvent
    )
}

/// 以 Fake Adapter 餵入 Session，回傳處理完後的 Session Store。
@MainActor
private func startedStore(with sessions: [AgentSession]) async -> SessionStore {
    let adapter = FakeHerdrAdapter(snapshot: SessionSnapshot(sessions: sessions))
    adapter.finish()
    let store = SessionStore(adapter: adapter)
    await store.start()
    return store
}

/// 依目前設定產生選單列文字。
@MainActor
private func menuBarText(_ store: SessionStore, _ settings: AppSettings) -> String {
    MenuBarSummaryFormatter.text(for: MenuBarSummary(snapshot: store.snapshot, settings: settings))
}

@MainActor
struct AppSettingsTests {
    @Test func freshSettingsUseTheDocumentedDefaults() {
        let settings = AppSettings(store: InMemorySettingsStore())

        #expect(settings.alwaysShowZeroCounts == false)
        #expect(settings.showDoneCount == false)
        #expect(settings.menuBarMode == .counts)
        #expect(settings.sortRule == .priority)
        #expect(settings.animationsEnabled == true)
        #expect(settings.lowDistractionAlerts == true)
    }

    @Test func changedSettingsSurviveARestartWithTheSameStore() {
        let store = InMemorySettingsStore()
        let beforeRestart = AppSettings(store: store)
        beforeRestart.alwaysShowZeroCounts = true
        beforeRestart.showDoneCount = true
        beforeRestart.menuBarMode = .fewCharacters
        beforeRestart.sortRule = .workspaceName
        beforeRestart.animationsEnabled = false
        beforeRestart.lowDistractionAlerts = false

        let afterRestart = AppSettings(store: store)

        #expect(afterRestart.alwaysShowZeroCounts == true)
        #expect(afterRestart.showDoneCount == true)
        #expect(afterRestart.menuBarMode == .fewCharacters)
        #expect(afterRestart.sortRule == .workspaceName)
        #expect(afterRestart.animationsEnabled == false)
        #expect(afterRestart.lowDistractionAlerts == false)
    }

    @Test func turningAlwaysShowZeroCountsOnAndOffChangesTheMenuBarTextImmediately() async {
        let store = await startedStore(with: [session("w1", rawState: "working")])
        let settings = AppSettings(store: InMemorySettingsStore())

        #expect(menuBarText(store, settings) == "⚒ 1")

        settings.alwaysShowZeroCounts = true
        #expect(menuBarText(store, settings) == "⚒ 1  ✋ 0  💤 0")

        settings.alwaysShowZeroCounts = false
        #expect(menuBarText(store, settings) == "⚒ 1")
    }

    @Test func showDoneCountAddsTheDoneCategoryAfterIdleAndDropsTheMarkerForDone() async {
        let store = await startedStore(with: [
            session("w1", rawState: "working"),
            session("a1", rawState: "blocked"),
            session("i1", rawState: "idle"),
            session("d1", rawState: "done"),
            session("d2", rawState: "done"),
        ])
        let settings = AppSettings(store: InMemorySettingsStore())

        #expect(menuBarText(store, settings) == "⚒ 1  ✋ 1  💤 1 •")

        settings.showDoneCount = true
        let summary = MenuBarSummary(snapshot: store.snapshot, settings: settings)
        #expect(summary.items == [
            MenuBarSummary.Item(state: .working, icon: "⚒", count: 1, isVisible: true),
            MenuBarSummary.Item(state: .needsApproval, icon: "✋", count: 1, isVisible: true),
            MenuBarSummary.Item(state: .idle, icon: "💤", count: 1, isVisible: true),
            MenuBarSummary.Item(state: .done, icon: "✓", count: 2, isVisible: true),
        ])
        #expect(summary.hasHiddenStates == false)
        #expect(MenuBarSummaryFormatter.text(for: summary) == "⚒ 1  ✋ 1  💤 1  ✓ 2")
    }

    @Test(arguments: ["failed", "thinking"])
    func showDoneCountStillMarksErrorAndUnknown(hiddenRawState: String) async {
        let store = await startedStore(with: [
            session("w1", rawState: "working"),
            session("d1", rawState: "done"),
            session("h1", rawState: hiddenRawState),
        ])
        let settings = AppSettings(store: InMemorySettingsStore())
        settings.showDoneCount = true

        #expect(menuBarText(store, settings) == "⚒ 1  ✓ 1 •")
    }

    @Test func zeroDoneCountFollowsTheAlwaysShowZeroRule() async {
        let store = await startedStore(with: [session("w1", rawState: "working")])
        let settings = AppSettings(store: InMemorySettingsStore())
        settings.showDoneCount = true

        #expect(menuBarText(store, settings) == "⚒ 1")

        settings.alwaysShowZeroCounts = true
        #expect(menuBarText(store, settings) == "⚒ 1  ✋ 0  💤 0  ✓ 0")
    }

    @Test func changingASettingNotifiesObserversOfTheSummary() async {
        let store = await startedStore(with: [session("w1", rawState: "working")])
        let settings = AppSettings(store: InMemorySettingsStore())
        let changeCount = OSAllocatedUnfairLock(initialState: 0)

        withObservationTracking {
            _ = MenuBarSummary(snapshot: store.snapshot, settings: settings)
        } onChange: {
            changeCount.withLock { $0 += 1 }
        }
        settings.showDoneCount = true

        #expect(changeCount.withLock { $0 } == 1)
    }

    @Test func menuBarTextAfterARestartMatchesTheSettingsChosenBeforeIt() async {
        let sessionStore = await startedStore(with: [
            session("w1", rawState: "working"),
            session("d1", rawState: "done"),
        ])
        let settingsStore = InMemorySettingsStore()
        let beforeRestart = AppSettings(store: settingsStore)
        beforeRestart.alwaysShowZeroCounts = true
        beforeRestart.showDoneCount = true

        let afterRestart = AppSettings(store: settingsStore)

        #expect(menuBarText(sessionStore, afterRestart) == "⚒ 1  ✋ 0  💤 0  ✓ 1")
    }

    @Test func unrecognizedStoredValuesFallBackToDefaults() {
        let store = InMemorySettingsStore()
        store.set("characters", forKey: AppSettings.Key.menuBarMode)
        store.set("alphabetical", forKey: AppSettings.Key.sortRule)

        let settings = AppSettings(store: store)

        #expect(settings.menuBarMode == .counts)
        #expect(settings.sortRule == .priority)
    }

    @Test func userDefaultsStoreKeepsSettingsAcrossARestart() throws {
        let suiteName = "IdleVillagerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let beforeRestart = AppSettings(store: UserDefaultsSettingsStore(defaults: defaults))
        #expect(beforeRestart.alwaysShowZeroCounts == false)
        #expect(beforeRestart.menuBarMode == .counts)
        beforeRestart.alwaysShowZeroCounts = true
        beforeRestart.menuBarMode = .fewCharacters

        let afterRestart = AppSettings(store: UserDefaultsSettingsStore(defaults: defaults))

        #expect(afterRestart.alwaysShowZeroCounts == true)
        #expect(afterRestart.showDoneCount == false)
        #expect(afterRestart.menuBarMode == .fewCharacters)
    }
}
