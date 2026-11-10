import Foundation
import Observation
import os
import Testing
import IdleVillagerCore

@MainActor
struct PopoverBackgroundSettingTests {
    @Test func translucentBackgroundIsOffByDefault() {
        let settings = AppSettings(store: InMemorySettingsStore())

        #expect(settings.translucentPopoverBackground == false)
        #expect(settings.popoverBackgroundStyle(reduceTransparency: false) == .opaque)
    }

    @Test func translucentBackgroundSurvivesARestartWithTheSameStore() {
        let store = InMemorySettingsStore()
        let beforeRestart = AppSettings(store: store)
        beforeRestart.translucentPopoverBackground = true

        #expect(store.bool(forKey: AppSettings.Key.translucentPopoverBackground) == true)
        #expect(AppSettings(store: store).translucentPopoverBackground == true)

        beforeRestart.translucentPopoverBackground = false

        #expect(AppSettings(store: store).translucentPopoverBackground == false)
    }

    @Test func aMissingOrUnreadableStoredValueFallsBackToOff() {
        let store = InMemorySettingsStore()
        // A value of the wrong type (e.g. written by a future version as a string) is not a Bool.
        store.set("translucent", forKey: AppSettings.Key.translucentPopoverBackground)

        #expect(AppSettings(store: store).translucentPopoverBackground == false)
        #expect(AppSettings(store: InMemorySettingsStore()).translucentPopoverBackground == false)
    }

    @Test func userDefaultsStoreKeepsTheTranslucentBackgroundAcrossARestart() throws {
        let suiteName = "IdleVillagerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let beforeRestart = AppSettings(store: UserDefaultsSettingsStore(defaults: defaults))
        #expect(beforeRestart.translucentPopoverBackground == false)
        beforeRestart.translucentPopoverBackground = true

        let afterRestart = AppSettings(store: UserDefaultsSettingsStore(defaults: defaults))

        #expect(afterRestart.translucentPopoverBackground == true)
    }

    @Test func togglingTheSettingNotifiesObserversOfTheBackgroundStyle() {
        let settings = AppSettings(store: InMemorySettingsStore())
        let changeCount = OSAllocatedUnfairLock(initialState: 0)

        withObservationTracking {
            _ = settings.popoverBackgroundStyle(reduceTransparency: false)
        } onChange: {
            changeCount.withLock { $0 += 1 }
        }
        settings.translucentPopoverBackground = true

        #expect(changeCount.withLock { $0 } == 1)
        #expect(settings.popoverBackgroundStyle(reduceTransparency: false) == .translucent)
    }

    @Test func otherSettingsDoNotNotifyObserversOfTheBackgroundStyle() {
        let settings = AppSettings(store: InMemorySettingsStore())
        let changeCount = OSAllocatedUnfairLock(initialState: 0)

        withObservationTracking {
            _ = settings.popoverBackgroundStyle(reduceTransparency: false)
        } onChange: {
            changeCount.withLock { $0 += 1 }
        }
        settings.showDoneCount = true

        #expect(changeCount.withLock { $0 } == 0)
    }
}

struct PopoverBackgroundStyleTests {
    @Test(arguments: [
        (false, false, PopoverBackgroundStyle.opaque),
        (false, true, PopoverBackgroundStyle.opaque),
        (true, false, PopoverBackgroundStyle.translucent),
        (true, true, PopoverBackgroundStyle.opaque),
    ])
    func reduceTransparencyAlwaysFallsBackToOpaque(
        translucentEnabled: Bool, reduceTransparency: Bool, expected: PopoverBackgroundStyle
    ) {
        #expect(PopoverBackgroundStyle.resolve(
            translucentEnabled: translucentEnabled, reduceTransparency: reduceTransparency
        ) == expected)
    }

    @Test @MainActor func settingsAndReduceTransparencyCombineThroughTheSameRule() {
        let settings = AppSettings(store: InMemorySettingsStore())
        settings.translucentPopoverBackground = true

        #expect(settings.popoverBackgroundStyle(reduceTransparency: false) == .translucent)
        #expect(settings.popoverBackgroundStyle(reduceTransparency: true) == .opaque)
    }

    @Test func onlyTheTranslucentStyleAddsABackingUnderWorkspaceCards() throws {
        #expect(PopoverBackgroundStyle.opaque.workspaceCardBackingOpacity == nil)
        let backing = try #require(PopoverBackgroundStyle.translucent.workspaceCardBackingOpacity)
        #expect(backing > 0 && backing < 1)
    }

    @Test func onlyTheTranslucentStyleAddsAStrongerBackingUnderTheFooter() throws {
        #expect(PopoverBackgroundStyle.opaque.footerBackingOpacity == nil)
        let footer = try #require(PopoverBackgroundStyle.translucent.footerBackingOpacity)
        let card = try #require(PopoverBackgroundStyle.translucent.workspaceCardBackingOpacity)
        // The footer buttons have a light bezel, so they need more backing than the cards to stay readable
        // over a bright desktop.
        #expect(footer > card && footer < 1)
    }
}
