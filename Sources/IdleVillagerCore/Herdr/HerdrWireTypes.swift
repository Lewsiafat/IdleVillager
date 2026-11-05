import Foundation

/// Herdr socket 協定的資料型別。
///
/// 欄位依 2026-11-05 在使用者環境匯出的 `herdr api schema --json`（protocol 22）與實際回應
/// （見 `docs/adr/0002-herdr-socket-api.md`）。只解碼本專案需要的 metadata 欄位；
/// `cwd`、`agent_session` 等其他欄位即使在回應中出現也不解碼、不保存。
public enum HerdrWire {
    /// `session.snapshot` 回傳的完整階層。
    public struct Snapshot: Decodable, Hashable, Sendable {
        public var workspaces: [Workspace]
        public var tabs: [Tab]
        public var panes: [Pane]
        public var agents: [Agent]
        public var focusedPaneID: String?

        enum CodingKeys: String, CodingKey {
            case workspaces, tabs, panes, agents
            case focusedPaneID = "focused_pane_id"
        }
    }

    public struct Workspace: Decodable, Hashable, Sendable {
        public var workspaceID: String
        public var label: String?

        enum CodingKeys: String, CodingKey {
            case workspaceID = "workspace_id"
            case label
        }
    }

    public struct Tab: Decodable, Hashable, Sendable {
        public var tabID: String
        public var workspaceID: String
        public var label: String?

        enum CodingKeys: String, CodingKey {
            case tabID = "tab_id"
            case workspaceID = "workspace_id"
            case label
        }
    }

    public struct Pane: Decodable, Hashable, Sendable {
        public var paneID: String
        public var label: String?

        enum CodingKeys: String, CodingKey {
            case paneID = "pane_id"
            case label
        }
    }

    /// `snapshot.agents[]` 與 `agent.get` / `agent.focus` 回傳的單一 Agent。
    public struct Agent: Decodable, Hashable, Sendable {
        public var terminalID: String
        public var paneID: String
        public var tabID: String
        public var workspaceID: String
        /// Agent 種類，例如 `claude`。
        public var agent: String?
        /// 五種值之一：`idle`、`working`、`blocked`、`done`、`unknown`。保留原字串，不在這裡解讀。
        public var agentStatus: String
        public var focused: Bool
        public var title: String?
        public var terminalTitleStripped: String?

        enum CodingKeys: String, CodingKey {
            case terminalID = "terminal_id"
            case paneID = "pane_id"
            case tabID = "tab_id"
            case workspaceID = "workspace_id"
            case agent
            case agentStatus = "agent_status"
            case focused
            case title
            case terminalTitleStripped = "terminal_title_stripped"
        }
    }

    /// 錯誤回應的內容。已觀察到的 `code`：`invalid_request`、`agent_not_found`。
    public struct RPCError: Decodable, Hashable, Sendable, Error {
        public var code: String
        public var message: String?

        public static let agentNotFound = "agent_not_found"
    }

    /// 一則回應：成功時有 `result`，失敗時有 `error`。
    public struct Response<Result: Decodable & Sendable>: Decodable, Sendable {
        public var id: String?
        public var result: Result?
        public var error: RPCError?
    }

    /// `session.snapshot` 的 `result`。
    public struct SnapshotResult: Decodable, Sendable {
        public var snapshot: Snapshot
    }

    /// `agent.get` 與 `agent.focus` 的 `result`。
    public struct AgentResult: Decodable, Sendable {
        public var agent: Agent
    }

    /// `ping` 的 `result`。
    public struct PingResult: Decodable, Sendable {
        public var version: String?
        public var `protocol`: Int?
    }

    /// 只看 `result.type` 的通用結果，例如 `subscription_started`。
    public struct TypedResult: Decodable, Sendable {
        public var type: String
    }

    /// 訂閱連線推送的一則事件：`{"event": "<kind>", "data": {...}}`。
    public struct EventEnvelope: Decodable, Hashable, Sendable {
        public var event: String
        public var data: EventData

        /// 事件種類的正規形式：生命週期事件以底線命名（`pane_created`），
        /// 狀態事件以點命名（`pane.agent_status_changed`），這裡統一成底線。
        public var normalizedKind: String { event.replacingOccurrences(of: ".", with: "_") }
    }

    /// 事件資料中本專案會用到的欄位；其餘欄位不解碼。
    public struct EventData: Decodable, Hashable, Sendable {
        public var paneID: String?
        public var workspaceID: String?
        public var agent: String?
        public var agentStatus: String?

        enum CodingKeys: String, CodingKey {
            case paneID = "pane_id"
            case workspaceID = "workspace_id"
            case agent
            case agentStatus = "agent_status"
        }
    }

    /// 本專案會送出的請求方法。刻意不包含 `agent.read`、`pane.read`、`agent.prompt`、`pane.send_*`
    /// 等會讀取終端內容或送入文字的方法。
    public enum Method: String, Sendable {
        case ping
        case sessionSnapshot = "session.snapshot"
        case agentGet = "agent.get"
        case agentFocus = "agent.focus"
        case eventsSubscribe = "events.subscribe"
    }

    /// 編碼一行請求（含結尾換行）。`params` 沒有參數時給空物件。
    public static func requestLine(id: String, method: Method, params: [String: any Sendable] = [:]) throws -> Data {
        let object: [String: Any] = ["id": id, "method": method.rawValue, "params": params]
        var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        data.append(0x0A)
        return data
    }

    public static func decode<T: Decodable>(_ type: T.Type, from line: Data) throws -> T {
        try JSONDecoder().decode(type, from: line)
    }
}
