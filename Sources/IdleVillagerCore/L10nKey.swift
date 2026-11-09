/// Every key in `Localizable.strings`. Both `en.lproj` and `zh-Hant.lproj` must define exactly these keys
/// with the same `{name}` placeholders (checked by `LocalizationTests`).
///
/// Count-dependent texts use a `.one` / `.other` key pair, picked by `LocalizedStrings.countText`.
public enum L10nKey: String, CaseIterable, Hashable, Sendable {
    // MARK: Normalized state short texts
    case stateWorking = "state.working"
    case stateNeedsApproval = "state.needsApproval"
    case stateDone = "state.done"
    case stateIdle = "state.idle"
    case stateError = "state.error"
    case stateUnknown = "state.unknown"

    // MARK: Separators
    /// Joins items of a list, e.g. the states in a conflict note.
    case listSeparator = "separator.list"
    /// Joins the clauses of an accessibility description.
    case clauseSeparator = "separator.clause"

    // MARK: Session list and stale data
    case staleSuffix = "row.staleSuffix"
    case conflictNote = "row.conflictNote"
    case agentCountOne = "count.agents.one"
    case agentCountOther = "count.agents.other"
    case emptyConnected = "empty.connected"
    case emptyDisconnected = "empty.disconnected"

    // MARK: Connection
    case connectionConnected = "connection.connected"
    case connectionNotConnected = "connection.notConnected"
    case connectionDisconnected = "connection.disconnected"
    case connectionReconnecting = "connection.reconnecting"

    // MARK: Footer
    case footerSource = "footer.source"
    case footerNeverUpdated = "footer.neverUpdated"
    case footerLastUpdated = "footer.lastUpdated"
    case footerStaleNotice = "footer.staleNotice"
    case footerQuit = "footer.quit"
    case footerSettings = "footer.settings"
    case timeJustNow = "time.justNow"
    case timeSecondsAgoOne = "time.secondsAgo.one"
    case timeSecondsAgoOther = "time.secondsAgo.other"
    case timeMinutesAgoOne = "time.minutesAgo.one"
    case timeMinutesAgoOther = "time.minutesAgo.other"
    case timeHoursAgoOne = "time.hoursAgo.one"
    case timeHoursAgoOther = "time.hoursAgo.other"
    case timeDaysAgoOne = "time.daysAgo.one"
    case timeDaysAgoOther = "time.daysAgo.other"

    // MARK: Menu bar
    case menuBarDisconnected = "menuBar.disconnected"
    case menuBarZeroAgents = "menuBar.zeroAgents"
    case menuBarNoAgentsAccessibility = "menuBar.accessibility.noAgents"
    case menuBarStateCountAccessibility = "menuBar.accessibility.stateCount"
    case menuBarHiddenWithDoneShownAccessibility = "menuBar.accessibility.hiddenErrorUnknown"
    case menuBarHiddenAccessibility = "menuBar.accessibility.hiddenDoneErrorUnknown"
    case menuBarCharacterAccessibility = "menuBar.accessibility.character"

    // MARK: Popover
    case dismissFocusFailure = "popover.dismissFailure"
    case tabAccessibilityOne = "popover.tab.accessibility.one"
    case tabAccessibilityOther = "popover.tab.accessibility.other"
    case tabCollapsed = "popover.tab.collapsed"
    case tabExpanded = "popover.tab.expanded"
    case tabToggleHint = "popover.tab.toggleHint"
    case rowFocusHint = "popover.row.focusHint"

    // MARK: Focus failures
    case focusTargetNotFound = "focus.targetNotFound"
    case focusUnsupported = "focus.unsupported"
    case focusDisconnected = "focus.disconnected"
    case focusWindowNotBroughtToFront = "focus.windowNotBroughtToFront"
    case focusDemoMode = "focus.demoMode"
    case focusBanner = "focus.banner"

    // MARK: Source and version
    case sourceDemo = "source.demo"
    case versionDevelopment = "version.development"
    case versionDevelopmentAccessibility = "version.accessibility.development"
    case versionReleaseAccessibility = "version.accessibility.release"

    // MARK: Demo data
    case demoTabAPI = "demo.tab.api"
    case demoTabTests = "demo.tab.tests"
    case demoTabUI = "demo.tab.ui"
    case demoWaitingReason = "demo.waitingReason"

    // MARK: Settings
    case settingsMenuBarSection = "settings.menuBar.section"
    case settingsMenuBarMode = "settings.menuBar.mode"
    case settingsModeCounts = "settings.menuBar.mode.counts"
    case settingsModeFewCharacters = "settings.menuBar.mode.fewCharacters"
    case settingsAlwaysShowZeroCounts = "settings.menuBar.alwaysShowZeroCounts"
    case settingsShowDoneCount = "settings.menuBar.showDoneCount"
    case settingsPreviewHeader = "settings.preview.header"
    case settingsPreviewFooter = "settings.preview.footer"
    case settingsBehaviorSection = "settings.behavior.section"
    case settingsSortRule = "settings.behavior.sortRule"
    case settingsSortPriority = "settings.behavior.sortRule.priority"
    case settingsSortWorkspaceName = "settings.behavior.sortRule.workspaceName"
    case settingsSortFixed = "settings.behavior.sortRule.fixed"
    case settingsAnimations = "settings.behavior.animations"
    case settingsLowDistractionAlerts = "settings.behavior.lowDistractionAlerts"
    case settingsLowDistractionAlertsDetail = "settings.behavior.lowDistractionAlerts.detail"
}
