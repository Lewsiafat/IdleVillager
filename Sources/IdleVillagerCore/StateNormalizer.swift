import Foundation

/// 正規化一個 Session 狀態訊號的結果。
public struct NormalizationResult: Hashable, Sendable {
    public var state: NormalizedState
    /// 訊號互相衝突時的非敏感描述，只含正規化狀態名稱；沒有衝突時為 nil。
    public var conflictNote: String?

    public init(state: NormalizedState, conflictNote: String? = nil) {
        self.state = state
        self.conflictNote = conflictNote
    }
}

/// 把 Adapter 的 rawState 與 stateSource 轉成六種正規化狀態之一的純函式。
public enum StateNormalizer {
    /// rawState 到正規化狀態的對應表，這是唯一定義鍵集合的地方。
    ///
    /// 整張表都是暫定的：在 #8 於使用者環境確認 Herdr 實際送出的 rawState 值之前，
    /// 所有鍵都只是推測，確認後要逐一重新校對。語意不明確的值（例如 `blocked`，
    /// 可能是等核准，也可能是錯誤或卡住）刻意不放進表中，讓它落到 Unknown。
    /// 比對時大小寫不敏感，底線與連字號視為相同。
    public static let rawStateTable: [String: NormalizedState] = [
        "working": .working,
        "running": .working,
        "busy": .working,
        "needsApproval": .needsApproval,
        "waiting_for_approval": .needsApproval,
        "awaiting_input": .needsApproval,
        "done": .done,
        "completed": .done,
        "idle": .idle,
        "error": .error,
        "failed": .error,
    ]

    private static let lookup: [String: NormalizedState] = Dictionary(
        uniqueKeysWithValues: rawStateTable.map { (canonicalKey($0.key), $0.value) }
    )

    /// 正規化一個 Session 目前的狀態訊號。
    public static func normalize(_ session: AgentSession) -> NormalizationResult {
        normalize(rawState: session.rawState, stateSource: session.stateSource)
    }

    /// 正規化一組 rawState 與 stateSource。
    public static func normalize(rawState: String, stateSource: StateSource) -> NormalizationResult {
        // 只有明確事件能推導出非 unknown 的狀態；間接訊號絕不推導出 idle。
        guard stateSource == .explicitEvent else { return NormalizationResult(state: .unknown) }
        let tokens = rawState
            .split(separator: signalSeparator)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var states: Set<NormalizedState> = []
        for token in tokens {
            // 任一訊號無法對應就整體視為 unknown；未對應的原始字串不放進描述，避免帶出自由文字。
            guard let state = lookup[canonicalKey(token)] else { return NormalizationResult(state: .unknown) }
            states.insert(state)
        }
        // Needs Approval 優先於 Idle：兩者同時出現不算衝突。
        if states.contains(.needsApproval) { states.remove(.idle) }
        guard states.count > 1 else { return NormalizationResult(state: states.first ?? .unknown) }
        let names = NormalizedState.allCases.filter(states.contains).map(displayName)
        return NormalizationResult(state: .unknown, conflictNote: "訊號衝突：" + names.joined(separator: "、"))
    }

    /// rawState 內多個訊號的分隔字元。
    public static let signalSeparator: Character = "|"

    private static func displayName(_ state: NormalizedState) -> String {
        switch state {
        case .working: "Working"
        case .needsApproval: "Needs Approval"
        case .done: "Done"
        case .idle: "Idle"
        case .error: "Error"
        case .unknown: "Unknown"
        }
    }

    private static func canonicalKey(_ raw: String) -> String {
        raw.lowercased().replacingOccurrences(of: "-", with: "_")
    }
}
