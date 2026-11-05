import Foundation

/// 狀態訊號的來源種類。正規化規則只信任 `explicitEvent`。
public enum StateSource: String, Hashable, Sendable, Codable {
    /// Herdr 明確送出的狀態事件或狀態 API 回傳值。
    case explicitEvent
    /// 間接訊號，例如程序存活、CPU 使用率或終端輸出停滯。不可單獨推導出非 unknown 的狀態。
    case indirectSignal
    /// 來源沒有說明狀態從何而來。
    case unspecified
}

/// Adapter 回傳的單一 Agent Session metadata。
///
/// 只包含監控與定位所需的欄位，刻意不提供任何可放置對話內容、Prompt 或密鑰的欄位。
/// 唯一的自由文字欄位 `waitingReason` 也只能放來源提供的簡短 metadata。
public struct AgentSession: Hashable, Sendable {
    public var workspaceID: WorkspaceID
    public var workspaceName: String
    public var tabID: TabID
    public var tabName: String
    public var paneID: PaneID
    public var paneLabel: String
    public var agentSessionID: AgentSessionID
    /// 來源提供的 Agent 種類原始字串，例如 "claude"、"codex"。
    public var agentKind: String
    public var displayName: String
    /// 來源提供的原始狀態字串，尚未正規化。
    public var rawState: String
    public var updatedAt: Date
    public var stateSource: StateSource
    /// 可選的等待原因：來源提供的極短 metadata，例如「等待執行指令核准」，顯示在清單列的補充說明。
    ///
    /// 只能是簡短的狀態說明，**不得**包含對話內容、Prompt、指令全文、密碼或 API Key；
    /// Adapter 拿不到符合條件的短說明時必須給 nil。沒有等待原因時為 nil。
    public var waitingReason: String?

    public init(
        workspaceID: WorkspaceID,
        workspaceName: String,
        tabID: TabID,
        tabName: String,
        paneID: PaneID,
        paneLabel: String,
        agentSessionID: AgentSessionID,
        agentKind: String,
        displayName: String,
        rawState: String,
        updatedAt: Date,
        stateSource: StateSource,
        waitingReason: String? = nil
    ) {
        self.workspaceID = workspaceID
        self.workspaceName = workspaceName
        self.tabID = tabID
        self.tabName = tabName
        self.paneID = paneID
        self.paneLabel = paneLabel
        self.agentSessionID = agentSessionID
        self.agentKind = agentKind
        self.displayName = displayName
        self.rawState = rawState
        self.updatedAt = updatedAt
        self.stateSource = stateSource
        self.waitingReason = waitingReason
    }
}

/// Adapter 某一時刻的完整 Session 階層快照。
///
/// 階層（Workspace → Tab → Pane → Agent Session）由每個 `AgentSession` 帶的 ID 與名稱表達。
public struct SessionSnapshot: Hashable, Sendable {
    public var sessions: [AgentSession]

    public init(sessions: [AgentSession]) {
        self.sessions = sessions
    }

    public static let empty = SessionSnapshot(sessions: [])
}
