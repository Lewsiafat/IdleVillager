import Foundation

/// UI languages IdleVillager ships with. The raw value is the `.lproj` directory name.
public enum AppLanguage: String, CaseIterable, Hashable, Sendable {
    case english = "en"
    case traditionalChinese = "zh-Hant"

    /// Picks the UI language from the user's ordered preferred languages (`Locale.preferredLanguages`).
    ///
    /// Follows the macOS convention: the first preferred language IdleVillager supports wins.
    /// When none of them is English or Traditional Chinese, the result is English.
    public static func resolve(preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            if let language = match(identifier) { return language }
        }
        return .english
    }

    /// Maps one BCP 47 / Apple language identifier (e.g. `zh-Hant-TW`, `zh_TW`, `en-GB`) to a supported language.
    ///
    /// Chinese counts as Traditional when it has the `Hant` script, or no script but a TW, HK or MO region.
    /// Simplified Chinese (`Hans`) and bare `zh` are not supported and return nil.
    static func match(_ identifier: String) -> AppLanguage? {
        let subtags = identifier.lowercased()
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .map(String.init)
        guard let languageCode = subtags.first else { return nil }
        switch languageCode {
        case "en":
            return .english
        case "zh":
            let rest = subtags.dropFirst()
            if rest.contains("hant") { return .traditionalChinese }
            if rest.contains("hans") { return nil }
            if rest.contains(where: { ["tw", "hk", "mo"].contains($0) }) { return .traditionalChinese }
            return nil
        default:
            return nil
        }
    }
}

/// The string table of one UI language, loaded from `<language>.lproj/Localizable.strings`
/// in the IdleVillagerCore resource bundle.
public struct LocalizedStrings: Hashable, Sendable {
    public let language: AppLanguage
    let table: [String: String]

    public init(language: AppLanguage, table: [String: String]) {
        self.language = language
        self.table = table
    }

    /// The text for `key` with `{name}` placeholders replaced by `arguments`.
    ///
    /// A missing key returns the key's raw value, so a broken table is visible instead of silently empty.
    public func text(_ key: L10nKey, _ arguments: [String: String] = [:]) -> String {
        Self.substitute(table[key.rawValue] ?? key.rawValue, arguments)
    }

    /// Picks the `one` key when `count` is 1 and the `other` key otherwise, and fills `{count}`.
    public func countText(one: L10nKey, other: L10nKey, count: Int, _ arguments: [String: String] = [:]) -> String {
        var arguments = arguments
        arguments["count"] = String(count)
        return text(count == 1 ? one : other, arguments)
    }

    /// Replaces `{name}` placeholders in a single pass, so an argument value that itself contains
    /// `{...}` (e.g. a user-chosen Tab name) is never substituted again. Unknown placeholders are kept.
    static func substitute(_ template: String, _ arguments: [String: String]) -> String {
        guard !arguments.isEmpty else { return template }
        var output = ""
        var rest = template[...]
        while let open = rest.firstIndex(of: "{") {
            output.append(contentsOf: rest[..<open])
            let nameStart = rest.index(after: open)
            if let close = rest[nameStart...].firstIndex(of: "}"),
               let value = arguments[String(rest[nameStart..<close])] {
                output.append(contentsOf: value)
                rest = rest[rest.index(after: close)...]
            } else {
                output.append("{")
                rest = rest[nameStart...]
            }
        }
        output.append(contentsOf: rest)
        return output
    }

    /// Names of the `{name}` placeholders in `template`.
    static func placeholders(in template: String) -> Set<String> {
        var names: Set<String> = []
        var rest = template[...]
        while let open = rest.firstIndex(of: "{") {
            let nameStart = rest.index(after: open)
            guard let close = rest[nameStart...].firstIndex(of: "}") else { break }
            names.insert(String(rest[nameStart..<close]))
            rest = rest[rest.index(after: close)...]
        }
        return names
    }

    /// Parses the contents of a `.strings` file (old-style property list, text or binary) into a dictionary.
    static func parseStringsFile(_ data: Data) -> [String: String]? {
        (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: String]
    }

    /// Loads `language` from a resource bundle directory, using English for any key the language lacks.
    ///
    /// Returns an empty table (texts fall back to key names) when the bundle or its files cannot be read.
    static func load(language: AppLanguage, resourceBundleURL: URL?, fileManager: FileManager = .default) -> LocalizedStrings {
        func table(_ language: AppLanguage) -> [String: String] {
            guard let resourceBundleURL,
                  let fileURL = stringsFileURL(language: language, resourceBundleURL: resourceBundleURL, fileManager: fileManager),
                  let data = try? Data(contentsOf: fileURL) else { return [:] }
            return parseStringsFile(data) ?? [:]
        }
        var merged = table(.english)
        if language != .english {
            merged.merge(table(language)) { _, translated in translated }
        }
        return LocalizedStrings(language: language, table: merged)
    }

    /// Finds `<language>.lproj/Localizable.strings` in a resource bundle directory.
    ///
    /// Looks both in a flat bundle (SwiftPM) and in `Contents/Resources` (Xcode-style bundle), and matches the
    /// `.lproj` name case-insensitively, so the lookup does not depend on how the build tool laid out the bundle.
    static func stringsFileURL(language: AppLanguage, resourceBundleURL: URL, fileManager: FileManager = .default) -> URL? {
        let roots = [resourceBundleURL, resourceBundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)]
        let directoryName = "\(language.rawValue).lproj".lowercased()
        for root in roots {
            guard let entries = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }
            for entry in entries where entry.lastPathComponent.lowercased() == directoryName {
                let file = entry.appendingPathComponent("Localizable.strings")
                if fileManager.fileExists(atPath: file.path) { return file }
            }
        }
        return nil
    }
}

/// Entry point for user-facing text. Core models and App views read every string through here.
///
/// The process-wide language starts as Traditional Chinese, the product's original language, so tests are
/// deterministic regardless of the test machine's language. The App calls `useSystemLanguage()` once at launch,
/// before any UI or model is created. Tests that need another language wrap code in `withStrings(_:_:)`,
/// which only affects the current task and therefore never leaks into tests running in parallel.
public enum L10n {
    /// Name of the SwiftPM resource bundle that holds the `.lproj` string tables.
    public static let resourceBundleName = "IdleVillager_IdleVillagerCore.bundle"

    private static let processStrings = LockedValue(
        LocalizedStrings.load(language: .traditionalChinese, resourceBundleURL: locateResourceBundle())
    )
    private static let scopedStrings = TaskLocal<LocalizedStrings?>(wrappedValue: nil)

    /// The strings in effect for the current task.
    public static var current: LocalizedStrings {
        scopedStrings.get() ?? processStrings.get()
    }

    /// Resolves the language from the user's preferred languages (English when neither supported language is listed)
    /// and makes it the process-wide language. Returns the chosen language.
    @discardableResult
    public static func useSystemLanguage(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        let language = AppLanguage.resolve(preferredLanguages: preferredLanguages)
        processStrings.set(LocalizedStrings.load(language: language, resourceBundleURL: locateResourceBundle()))
        return language
    }

    /// Runs `operation` with `strings` as the current strings for this task only.
    public static func withStrings<R>(_ strings: LocalizedStrings, _ operation: () throws -> R) rethrows -> R {
        try scopedStrings.withValue(strings, operation: operation)
    }

    /// Shortcut for `current.text(_:_:)`.
    public static func text(_ key: L10nKey, _ arguments: [String: String] = [:]) -> String {
        current.text(key, arguments)
    }

    /// Shortcut for `current.countText(one:other:count:_:)`.
    public static func countText(one: L10nKey, other: L10nKey, count: Int, _ arguments: [String: String] = [:]) -> String {
        current.countText(one: one, other: other, count: count, arguments)
    }

    /// Finds the Core resource bundle without `Bundle.module` (which `fatalError`s inside a packaged `.app`,
    /// see `ResourceBundleLocator`).
    ///
    /// First looks around the main bundle (`.app` `Contents/Resources`, or the executable's directory under
    /// `swift run`). Then looks next to the bundle that contains this code: under `swift test` that is the
    /// `.xctest` bundle, whose sibling directory holds the resource bundles.
    static func locateResourceBundle() -> URL? {
        if let bundle = ResourceBundleLocator.bundle(named: resourceBundleName) {
            return bundle.bundleURL
        }
        let codeBundle = Bundle(for: CodeBundleMarker.self)
        return ResourceBundleLocator.locate(
            bundleName: resourceBundleName,
            in: [codeBundle.bundleURL.deletingLastPathComponent()]
        )
    }
}

/// Identifies the binary image that contains IdleVillagerCore, for `Bundle(for:)`.
private final class CodeBundleMarker {}

/// A value guarded by a lock, for process-wide state shared across threads.
private final class LockedValue<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func get() -> Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ newValue: Value) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }
}
