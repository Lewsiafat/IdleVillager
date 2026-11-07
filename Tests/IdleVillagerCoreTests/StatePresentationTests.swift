import Testing
@testable import IdleVillagerCore

struct StatePresentationTests {
    @Test(arguments: [
        (NormalizedState.working, "⚒", "幹活中", "Working"),
        (.needsApproval, "✋", "等核准", "Needs Approval"),
        (.done, "✓", "完成", "Done"),
        (.idle, "💤", "閒置", "Idle"),
        (.error, "!", "錯誤", "Error"),
        (.unknown, "?", "訊號不足", "Unknown"),
    ])
    func tableHoldsIconShortTextAndEnglishName(state: NormalizedState, icon: String, shortText: String, englishName: String) {
        #expect(state.presentation == StatePresentation(icon: icon, shortText: shortText, englishName: englishName))
        #expect(state.icon == icon)
        #expect(state.shortText == shortText)
    }

    @Test(arguments: [
        (NormalizedState.working, "hammer.fill"),
        (.needsApproval, "hand.raised.fill"),
        (.idle, "zzz"),
        (.done, "checkmark"),
        (.error, "exclamationmark"),
        (.unknown, "questionmark"),
    ])
    func symbolNameMapsEachStateToItsSFSymbol(state: NormalizedState, symbolName: String) {
        #expect(state.symbolName == symbolName)
    }

    @Test func priorityOrderCoversEveryStateOnce() {
        #expect(NormalizedState.priorityOrder == [.needsApproval, .error, .done, .working, .idle, .unknown])
        #expect(Set(NormalizedState.priorityOrder) == Set(NormalizedState.allCases))
        #expect(NormalizedState.priorityOrder.map(\.priorityRank) == Array(0..<NormalizedState.allCases.count))
    }

    @Test func highestPriorityPicksLowestRankAndDefaultsToUnknown() {
        #expect(NormalizedState.highestPriority([.idle, .done, .working]) == .done)
        #expect(NormalizedState.highestPriority([.unknown, .needsApproval]) == .needsApproval)
        #expect(NormalizedState.highestPriority([]) == .unknown)
    }

    @Test func menuBarSummaryItemsUseTheTableIcons() {
        var counts = StateCounts()
        counts.working = 1
        let summary = MenuBarSummary(counts: counts, connectionState: .connected, alwaysShowZero: true, showDoneCount: true)
        #expect(summary.items.map(\.icon) == ["⚒", "✋", "💤", "✓"])
        #expect(summary.items.allSatisfy { $0.icon == $0.state.icon })
    }
}
