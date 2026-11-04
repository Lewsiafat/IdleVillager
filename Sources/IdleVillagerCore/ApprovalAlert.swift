import Foundation

/// 低干擾提醒：待核准（Needs Approval）數量增加時，選單列短暫強調一次。
///
/// 這是純值 reducer。每次觀察到新的待核准數量就呼叫 `observe`，它和上一次的數量比較：
/// 數量增加且設定開啟時，產生一次持續 `duration` 秒的提醒（`alertUntil`）；
/// 減少或不變不觸發，設定關閉時永不觸發並清除進行中的提醒。
/// 第一次觀察只記下基準數量，不觸發。提醒只是一段時間描述，不含音效或系統通知，強調方式由 App 層決定。
public struct ApprovalAlertTracker: Hashable, Sendable {
    /// 一次提醒的持續時間（秒）。
    public static let duration: TimeInterval = 3

    /// 上一次觀察到的待核准數量；尚未觀察過時為 nil。
    public private(set) var lastCount: Int?
    /// 目前這次提醒的結束時間；沒有觸發過或已被清除時為 nil。到期後仍保留，以 `isAlerting(at:)` 判斷是否進行中。
    public private(set) var alertUntil: Date?

    public init() {}

    /// 比較前後兩次待核准數量的純規則：增加且開啟時回傳提醒結束時間，否則為 nil。
    public static func alertUntil(previousCount: Int, currentCount: Int, enabled: Bool, now: Date) -> Date? {
        guard enabled, currentCount > previousCount else { return nil }
        return now.addingTimeInterval(duration)
    }

    /// 記錄新的待核准數量並更新提醒。
    ///
    /// - Parameters:
    ///   - needsApprovalCount: 目前的待核准數量（`StoreSnapshot.counts.needsApproval`）。
    ///   - enabled: 低干擾提醒是否開啟（`AppSettings.lowDistractionAlerts`）。
    ///   - now: 目前時間，可注入以便測試。
    public mutating func observe(needsApprovalCount: Int, enabled: Bool, now: Date) {
        defer { lastCount = needsApprovalCount }
        guard enabled else {
            alertUntil = nil
            return
        }
        guard let lastCount else { return }
        if let until = Self.alertUntil(previousCount: lastCount, currentCount: needsApprovalCount, enabled: enabled, now: now) {
            alertUntil = until
        }
    }

    /// 在 `now` 時提醒是否仍在進行中；到達 `alertUntil` 即結束。
    public func isAlerting(at now: Date) -> Bool {
        guard let alertUntil else { return false }
        return now < alertUntil
    }
}

extension ApprovalAlertTracker {
    /// 依使用者設定（`AppSettings.lowDistractionAlerts`）記錄新的待核准數量。
    @MainActor
    public mutating func observe(needsApprovalCount: Int, settings: AppSettings, now: Date) {
        observe(needsApprovalCount: needsApprovalCount, enabled: settings.lowDistractionAlerts, now: now)
    }
}
