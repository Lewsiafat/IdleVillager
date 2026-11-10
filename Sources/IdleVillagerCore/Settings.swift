import Foundation
import Observation

/// 選單列的呈現模式。實際呈現由 `MenuBarCharacterMode` 依模式、連線狀態與 Session 數量決定。
public enum MenuBarMode: String, CaseIterable, Hashable, Sendable {
    /// 顯示各類別數量，例如 `⚒ 3  ✋ 2  💤 1`。
    case counts
    /// Agent 數量少時改以少數角色呈現。
    case fewCharacters
}

/// Popover 清單的排序規則，由 `SessionListModel(snapshot:sortRule:)` 套用。
public enum SortRule: String, CaseIterable, Hashable, Sendable {
    /// 依狀態優先序排列（Needs Approval 最前）。
    case priority
    /// Workspace 與 Tab 依名稱排列，列仍依狀態優先序。
    case workspaceName
    /// 固定順序：Workspace、Tab、列都依穩定 ID 排列，不因狀態改變而移動。
    case fixed
}

/// 偏好設定的鍵值儲存介面。正式環境用 `UserDefaultsSettingsStore`，測試用 `InMemorySettingsStore`。
public protocol SettingsStore: AnyObject {
    /// 讀取布林值；從未寫入過時回傳 nil。
    func bool(forKey key: String) -> Bool?
    /// 讀取字串；從未寫入過時回傳 nil。
    func string(forKey key: String) -> String?
    func set(_ value: Bool, forKey key: String)
    func set(_ value: String, forKey key: String)
}

/// 記憶體內的 `SettingsStore`，供測試與預覽使用。同一個實例可以模擬 App 重啟前後的偏好儲存。
public final class InMemorySettingsStore: SettingsStore {
    private var values: [String: Any] = [:]

    public init() {}

    public func bool(forKey key: String) -> Bool? { values[key] as? Bool }
    public func string(forKey key: String) -> String? { values[key] as? String }
    public func set(_ value: Bool, forKey key: String) { values[key] = value }
    public func set(_ value: String, forKey key: String) { values[key] = value }
}

/// 使用者偏好設定的可觀察模型。
///
/// 初始化時從 `SettingsStore` 讀回已儲存的值，之後每次改動都立即寫回。
/// 選單列摘要不自行讀取偏好儲存，只透過 `MenuBarSummary(snapshot:settings:)` 接收這裡的值。
@MainActor
@Observable
public final class AppSettings {
    /// 偏好儲存使用的鍵。
    public enum Key {
        public static let alwaysShowZeroCounts = "alwaysShowZeroCounts"
        public static let showDoneCount = "showDoneCount"
        public static let menuBarMode = "menuBarMode"
        public static let sortRule = "sortRule"
        public static let animationsEnabled = "animationsEnabled"
        public static let lowDistractionAlerts = "lowDistractionAlerts"
        public static let translucentPopoverBackground = "translucentPopoverBackground"
        public static let language = "language"
    }

    /// 值為 0 的類別也固定顯示在選單列。預設關。
    public var alwaysShowZeroCounts: Bool {
        didSet { store.set(alwaysShowZeroCounts, forKey: Key.alwaysShowZeroCounts) }
    }

    /// 在選單列顯示 Done 小計數 `✓ n`。預設關。
    public var showDoneCount: Bool {
        didSet { store.set(showDoneCount, forKey: Key.showDoneCount) }
    }

    /// 選單列呈現模式。預設 `counts`；選 `fewCharacters` 時由 `MenuBarCharacterMode` 決定是否顯示角色。
    public var menuBarMode: MenuBarMode {
        didSet { store.set(menuBarMode.rawValue, forKey: Key.menuBarMode) }
    }

    /// Popover 清單排序規則。預設 `priority`。
    public var sortRule: SortRule {
        didSet { store.set(sortRule.rawValue, forKey: Key.sortRule) }
    }

    /// 是否播放角色動畫。預設開；關閉時效果等同系統 Reduce Motion（見 `CharacterMotion`）。
    public var animationsEnabled: Bool {
        didSet { store.set(animationsEnabled, forKey: Key.animationsEnabled) }
    }

    /// 低干擾提醒：待核准數量增加時選單列短暫強調。預設開；見 `ApprovalAlertTracker`。
    public var lowDistractionAlerts: Bool {
        didSet { store.set(lowDistractionAlerts, forKey: Key.lowDistractionAlerts) }
    }

    /// Translucent popover background. Off by default (keeps the opaque look). The style actually drawn also
    /// depends on the system "Reduce transparency" setting; see `popoverBackgroundStyle(reduceTransparency:)`.
    public var translucentPopoverBackground: Bool {
        didSet { store.set(translucentPopoverBackground, forKey: Key.translucentPopoverBackground) }
    }

    /// Interface language. English by default, regardless of the macOS preferred languages.
    ///
    /// Only stores the choice. The App applies it with `L10n.use(_:)` at launch and when it changes, so Core
    /// tests that change this value never switch the process-wide language.
    public var language: AppLanguage {
        didSet { store.set(language.rawValue, forKey: Key.language) }
    }

    @ObservationIgnored private let store: any SettingsStore

    /// 從 `store` 讀回已儲存的設定；沒有儲存過或值無法辨識的欄位使用預設值。
    public init(store: any SettingsStore) {
        self.store = store
        alwaysShowZeroCounts = store.bool(forKey: Key.alwaysShowZeroCounts) ?? false
        showDoneCount = store.bool(forKey: Key.showDoneCount) ?? false
        menuBarMode = store.string(forKey: Key.menuBarMode).flatMap(MenuBarMode.init(rawValue:)) ?? .counts
        sortRule = store.string(forKey: Key.sortRule).flatMap(SortRule.init(rawValue:)) ?? .priority
        animationsEnabled = store.bool(forKey: Key.animationsEnabled) ?? true
        lowDistractionAlerts = store.bool(forKey: Key.lowDistractionAlerts) ?? true
        translucentPopoverBackground = store.bool(forKey: Key.translucentPopoverBackground) ?? false
        language = store.string(forKey: Key.language).flatMap(AppLanguage.init(rawValue:)) ?? .english
    }
}

/// 以 macOS 標準使用者偏好（`UserDefaults`）實作的 `SettingsStore`。
public final class UserDefaultsSettingsStore: SettingsStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func bool(forKey key: String) -> Bool? {
        defaults.object(forKey: key) as? Bool
    }

    public func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    public func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    public func set(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
