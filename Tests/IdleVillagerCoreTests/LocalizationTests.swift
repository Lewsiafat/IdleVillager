import Foundation
import Testing
@testable import IdleVillagerCore

/// Reads a string table straight from the source tree, independent of how the build tool packages resources.
private func sourceTable(_ language: AppLanguage) throws -> [String: String] {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // IdleVillagerCoreTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // package root
        .appendingPathComponent("Sources/IdleVillagerCore/Resources/\(language.rawValue).lproj/Localizable.strings")
    let data = try Data(contentsOf: url)
    return try #require(LocalizedStrings.parseStringsFile(data))
}

private func englishStrings() throws -> LocalizedStrings {
    LocalizedStrings(language: .english, table: try sourceTable(.english))
}

/// True when `text` contains CJK ideographs, CJK punctuation or full-width forms.
private func containsCJK(_ text: String) -> Bool {
    text.unicodeScalars.contains { scalar in
        switch scalar.value {
        case 0x3000...0x303F, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0xFF00...0xFFEF: true
        default: false
        }
    }
}

struct LocalizationResourceTests {
    @Test func everyLanguageDefinesExactlyTheKnownKeys() throws {
        let expected = Set(L10nKey.allCases.map(\.rawValue))
        for language in AppLanguage.allCases {
            let keys = Set(try sourceTable(language).keys)
            #expect(keys == expected, "\(language.rawValue): missing \(expected.subtracting(keys)), extra \(keys.subtracting(expected))")
        }
    }

    @Test func placeholdersMatchAcrossLanguages() throws {
        let english = try sourceTable(.english)
        let chinese = try sourceTable(.traditionalChinese)
        for key in L10nKey.allCases {
            let englishPlaceholders = LocalizedStrings.placeholders(in: english[key.rawValue] ?? "")
            let chinesePlaceholders = LocalizedStrings.placeholders(in: chinese[key.rawValue] ?? "")
            #expect(englishPlaceholders == chinesePlaceholders, "\(key.rawValue)")
        }
    }

    @Test func noTranslationIsEmpty() throws {
        for language in AppLanguage.allCases {
            for (key, value) in try sourceTable(language) {
                #expect(!value.isEmpty, "\(language.rawValue) \(key)")
            }
        }
    }

    @Test func englishTableHasNoCJKCharacters() throws {
        for (key, value) in try sourceTable(.english) {
            #expect(!containsCJK(value), "\(key) = \(value)")
        }
    }

    /// The packaged resource bundle (built by SwiftPM from `Resources`) must hold the same tables as the source tree.
    @Test func builtResourceBundleMatchesSourceTables() throws {
        let bundleURL = try #require(L10n.locateResourceBundle())
        for language in AppLanguage.allCases {
            let loaded = LocalizedStrings.load(language: language, resourceBundleURL: bundleURL)
            let source = try sourceTable(language)
            #expect(loaded.table == source, "\(language.rawValue)")
        }
    }

    /// Tests rely on this: until the App calls `L10n.use(_:)`, Core speaks Traditional Chinese.
    @Test func processDefaultIsTraditionalChinese() {
        #expect(L10n.current.language == .traditionalChinese)
        #expect(NormalizedState.working.shortText == "幹活中")
    }

    @Test func scopedStringsDoNotLeakOutOfTheScope() throws {
        let english = try englishStrings()
        let inside: String = L10n.withStrings(english) { NormalizedState.working.shortText }
        #expect(inside == "Working")
        #expect(NormalizedState.working.shortText == "幹活中")
    }
}

struct LocalizedStringsLookupTests {
    @Test func substitutesPlaceholdersInOnePass() {
        // A value that looks like a placeholder (e.g. a Tab named "{count}") is not substituted again.
        #expect(LocalizedStrings.substitute("{name}, {count}", ["name": "{count}", "count": "2"]) == "{count}, 2")
        #expect(LocalizedStrings.substitute("{a} {missing}", ["a": "x"]) == "x {missing}")
        #expect(LocalizedStrings.substitute("no {brace", ["brace": "x"]) == "no {brace")
        #expect(LocalizedStrings.substitute("plain", [:]) == "plain")
    }

    @Test func countTextPicksOneOrOther() throws {
        let english = try englishStrings()
        #expect(english.countText(one: .agentCountOne, other: .agentCountOther, count: 1) == "1 Agent")
        #expect(english.countText(one: .agentCountOne, other: .agentCountOther, count: 0) == "0 Agents")
        #expect(english.countText(one: .agentCountOne, other: .agentCountOther, count: 2) == "2 Agents")
    }

    @Test func missingKeyShowsTheKeyName() {
        let empty = LocalizedStrings(language: .english, table: [:])
        #expect(empty.text(.stateWorking) == "state.working")
    }

    @Test func loadFallsBackToEnglishAndFindsLprojCaseInsensitively() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("IdleVillagerLocalizationTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        // Xcode-style layout (Contents/Resources) with a lower-cased zh-Hant directory.
        let resources = root.appendingPathComponent("Contents/Resources", isDirectory: true)
        let english = resources.appendingPathComponent("en.lproj", isDirectory: true)
        let chinese = resources.appendingPathComponent("zh-hant.lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: english, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: chinese, withIntermediateDirectories: true)
        try Data("\"state.working\" = \"Working\";\n\"state.idle\" = \"Idle\";\n".utf8)
            .write(to: english.appendingPathComponent("Localizable.strings"))
        try Data("/* comment */\n\"state.working\" = \"幹活中\";\n".utf8)
            .write(to: chinese.appendingPathComponent("Localizable.strings"))

        let strings = LocalizedStrings.load(language: .traditionalChinese, resourceBundleURL: root)
        #expect(strings.text(.stateWorking) == "幹活中")
        #expect(strings.text(.stateIdle) == "Idle")

        let missingBundle = LocalizedStrings.load(language: .english, resourceBundleURL: nil)
        #expect(missingBundle.text(.stateIdle) == "state.idle")
    }
}

private let resolutionCases: [([String], AppLanguage)] = [
    (["en-US"], .english),
    (["en"], .english),
    (["zh-Hant-TW", "en-TW"], .traditionalChinese),
    (["zh-Hant"], .traditionalChinese),
    (["zh-Hant-HK"], .traditionalChinese),
    (["zh-TW"], .traditionalChinese),
    (["zh_HK"], .traditionalChinese),
    (["zh-MO"], .traditionalChinese),
    // Unsupported languages fall back to English.
    (["zh-Hans-CN"], .english),
    (["zh"], .english),
    (["ja-JP"], .english),
    (["fr-FR", "de-DE"], .english),
    ([], .english),
    // Like macOS, the first supported language in the preference list wins.
    (["ja-JP", "zh-Hant-TW"], .traditionalChinese),
    (["fr-FR", "en-GB", "zh-Hant-TW"], .english),
]

struct AppLanguageSwitchTests {
    @Test func stringsForALanguageLoadThatLanguageFromTheResourceBundle() {
        #expect(L10n.strings(for: .english).text(.settingsLanguage) == "Language")
        #expect(L10n.strings(for: .traditionalChinese).text(.settingsLanguage) == "語言")
    }

    @Test func pickerNamesAreWrittenInTheLanguageItself() {
        #expect(AppLanguage.english.nativeName == "English")
        #expect(AppLanguage.traditionalChinese.nativeName == "繁體中文")
    }
}

struct AppLanguageResolutionTests {
    @Test(arguments: resolutionCases)
    func resolvesFromPreferredLanguages(preferredLanguages: [String], expected: AppLanguage) {
        #expect(AppLanguage.resolve(preferredLanguages: preferredLanguages) == expected)
    }
}

/// English UI output of the Core presentation models: exact texts for the main cases, and no CJK anywhere.
struct EnglishPresentationTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private static func session(_ id: String, rawState: String, tabName: String = "API") -> AgentSession {
        AgentSession(
            workspaceID: WorkspaceID("ws"),
            workspaceName: "Backend Project",
            tabID: TabID("tab-\(tabName)"),
            tabName: tabName,
            paneID: PaneID("pane-\(id)"),
            paneLabel: "Pane \(id)",
            agentSessionID: AgentSessionID(id),
            agentKind: "claude",
            displayName: "Claude Code",
            rawState: rawState,
            updatedAt: now,
            stateSource: .explicitEvent
        )
    }

    private static func snapshot(
        _ connectionState: ConnectionState,
        sessions: [AgentSession],
        lastUpdatedAt: Date?
    ) -> StoreSnapshot {
        let result = StoreSnapshot.normalizedEntries(from: sessions) { _ in connectionState != .connected }
        return StoreSnapshot(
            connectionState: connectionState,
            sourceDescription: SourceDescription.demo,
            lastUpdatedAt: lastUpdatedAt,
            sessions: result.sessions,
            counts: result.counts
        )
    }

    private static func texts(of model: SessionListModel) -> [String] {
        var texts = [
            model.headerStatusText,
            model.footer.sourceName,
            model.footer.connectionText,
            model.footer.lastUpdatedText(now: now),
        ]
        if let emptyStateText = model.emptyStateText { texts.append(emptyStateText) }
        if let staleNotice = model.footer.staleNotice { texts.append(staleNotice) }
        for workspace in model.workspaces {
            for tab in workspace.tabs {
                texts.append(tab.name)
                for row in tab.rows {
                    texts.append(row.stateText)
                    if let detail = row.detail { texts.append(detail) }
                }
            }
        }
        return texts
    }

    /// Connected (8 sessions incl. a conflict), connected with 1, disconnected, never connected, zero, reconnecting.
    private static func makeModels() -> [SessionListModel] {
        let sessions = SessionSnapshot.demo.sessions + [session("conflict", rawState: "working|idle")]
        return [
            SessionListModel(snapshot: snapshot(.connected, sessions: sessions, lastUpdatedAt: now - 180)),
            SessionListModel(snapshot: snapshot(.connected, sessions: [session("one", rawState: "idle")], lastUpdatedAt: now)),
            SessionListModel(snapshot: snapshot(.disconnected, sessions: sessions, lastUpdatedAt: now - 60)),
            SessionListModel(snapshot: snapshot(.disconnected, sessions: [], lastUpdatedAt: nil)),
            SessionListModel(snapshot: snapshot(.connected, sessions: [], lastUpdatedAt: now)),
            SessionListModel(snapshot: snapshot(.reconnecting, sessions: [], lastUpdatedAt: now)),
        ]
    }

    @Test func stateShortTextsAreEnglish() throws {
        let english = try englishStrings()
        let texts: [String] = L10n.withStrings(english) { NormalizedState.allCases.map(\.shortText) }
        #expect(texts == ["Working", "Needs Approval", "Done", "Idle", "Error", "Unknown"])
    }

    @Test func sessionListModelSpeaksEnglish() throws {
        let english = try englishStrings()
        // Models are built inside the scope: row texts and conflict notes are produced while building.
        let models: [SessionListModel] = L10n.withStrings(english) { Self.makeModels() }
        let connected = models[0]
        let single = models[1]
        let disconnected = models[2]
        let neverConnected = models[3]
        let zero = models[4]
        let reconnecting = models[5]

        let allTexts: [String] = L10n.withStrings(english) { models.flatMap { Self.texts(of: $0) } }
        for text in allTexts {
            #expect(!containsCJK(text), "\(text)")
        }

        L10n.withStrings(english) {
            #expect(connected.headerStatusText == "8 Agents")
            #expect(single.headerStatusText == "1 Agent")
            #expect(connected.footer.lastUpdatedText(now: Self.now) == "Last updated: 3 minutes ago")
            #expect(disconnected.footer.lastUpdatedText(now: Self.now) == "Last updated: 1 minute ago")
            #expect(single.footer.lastUpdatedText(now: Self.now) == "Last updated: just now")
            #expect(neverConnected.footer.lastUpdatedText(now: Self.now) == "Not updated yet")
            #expect(connected.footer.sourceName == "Demo data")
            #expect(connected.footer.connectionText == "Connected")
            #expect(disconnected.headerStatusText == "Disconnected")
            #expect(neverConnected.headerStatusText == "Not connected")
            #expect(reconnecting.headerStatusText == "Reconnecting")
            #expect(zero.emptyStateText == "No Agent sessions")
            #expect(neverConnected.emptyStateText == "Not connected. No session data to show.")
        }

        let rows = disconnected.workspaces.flatMap(\.tabs).flatMap(\.rows)
        #expect(rows.contains { $0.stateText == "Working (stale)" })
        #expect(rows.contains { $0.detail == "Signal conflict: Working, Idle" })
        #expect(rows.contains { $0.detail == "Waiting for approval to run a command" })
    }

    @Test(arguments: [
        (0.0, "Last updated: just now"),
        (10, "Last updated: 10 seconds ago"),
        (60, "Last updated: 1 minute ago"),
        (3_599, "Last updated: 59 minutes ago"),
        (3_600, "Last updated: 1 hour ago"),
        (7_200, "Last updated: 2 hours ago"),
        (86_400, "Last updated: 1 day ago"),
        (172_800, "Last updated: 2 days ago"),
    ])
    func lastUpdatedTextIsEnglish(elapsed: Double, expected: String) throws {
        let footer = SessionListModel.Footer(
            sourceName: "Herdr", connectionState: .connected, connectionText: "Connected",
            lastUpdatedAt: Self.now - elapsed
        )
        let english = try englishStrings()
        let text: String = L10n.withStrings(english) { footer.lastUpdatedText(now: Self.now) }
        #expect(text == expected)
    }

    @Test func menuBarFocusAndVersionTextsAreEnglish() throws {
        let reasons: [FocusFailureReason] = [.targetNotFound, .unsupported, .disconnected, .windowNotBroughtToFront, .demoMode]
        let english = try englishStrings()
        let texts: [String] = L10n.withStrings(english) {
            var texts = [
                MenuBarSummaryFormatter.disconnectedText,
                MenuBarSummaryFormatter.zeroAgentsText,
                AppVersionLabel.text(shortVersion: nil),
                AppVersionLabel.accessibilityText(shortVersion: nil),
                AppVersionLabel.accessibilityText(shortVersion: "0.1.0"),
            ]
            for reason in reasons {
                let failure = FocusFailure(sessionID: AgentSessionID("s"), paneID: PaneID("p"), reason: reason)
                texts.append(failure.message)
                texts.append(failure.bannerText)
            }
            let preview = StoreSnapshot.menuBarPreview(for: .counts)
            texts.append(preview.sourceDescription)
            texts.append(contentsOf: preview.sessions.map(\.session.tabName))
            texts.append(contentsOf: L10nKey.allCases.map { L10n.text($0) })
            return texts
        }
        for text in texts {
            #expect(!containsCJK(text), "\(text)")
        }
        #expect(texts[0] == "⚠ Disconnected")
        #expect(texts[1] == "0 Agents")
        #expect(texts[2] == "Development build")
        #expect(texts[4] == "IdleVillager version 0.1.0")
        #expect(texts.contains("Couldn't switch back: The target no longer exists"))
        #expect(texts.contains("Can't switch back in demo mode"))
    }
}
