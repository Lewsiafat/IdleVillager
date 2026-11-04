import Foundation
import Observation

/// 選單列的呈現模式。本票只定義與持久化，尚未接上行為。
public enum MenuBarMode: String, CaseIterable, Hashable, Sendable {
    /// 顯示各類別數量，例如 `⚒ 3  ✋ 2  💤 1`。
    case counts
    /// Agent 數量少時改以少數角色呈現。
    case fewCharacters
}

/// Popover 清單的排序規則。本票只定義與持久化，尚未接上行為。
public enum SortRule: String, CaseIterable, Hashable, Sendable {
    /// 依狀態優先序排列（Needs Approval 最前）。
    case priority
    /// 依 Workspace 名稱排列。
    case workspaceName
    /// 固定順序，不因狀態改變而移動。
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
    }

    /// 值為 0 的類別也固定顯示在選單列。預設關。
    public var alwaysShowZeroCounts: Bool {
        didSet { store.set(alwaysShowZeroCounts, forKey: Key.alwaysShowZeroCounts) }
    }

    /// 在選單列顯示 Done 小計數 `✓ n`。預設關。
    public var showDoneCount: Bool {
        didSet { store.set(showDoneCount, forKey: Key.showDoneCount) }
    }

    /// 預留：選單列呈現模式。預設 `counts`；本票尚未接上行為。
    public var menuBarMode: MenuBarMode {
        didSet { store.set(menuBarMode.rawValue, forKey: Key.menuBarMode) }
    }

    /// 預留：Popover 清單排序規則。預設 `priority`；本票尚未接上行為。
    public var sortRule: SortRule {
        didSet { store.set(sortRule.rawValue, forKey: Key.sortRule) }
    }

    /// 預留：是否播放動畫。預設開；本票尚未接上行為。
    public var animationsEnabled: Bool {
        didSet { store.set(animationsEnabled, forKey: Key.animationsEnabled) }
    }

    /// 預留：是否使用低干擾提醒。預設開；本票尚未接上行為。
    public var lowDistractionAlerts: Bool {
        didSet { store.set(lowDistractionAlerts, forKey: Key.lowDistractionAlerts) }
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
    }
}

extension MenuBarSummary {
    /// 依使用者設定產生摘要。設定值由呼叫端傳入，摘要本身不讀取偏好儲存。
    @MainActor
    public init(snapshot: StoreSnapshot, settings: AppSettings) {
        self.init(
            snapshot: snapshot,
            alwaysShowZero: settings.alwaysShowZeroCounts,
            showDoneCount: settings.showDoneCount
        )
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
