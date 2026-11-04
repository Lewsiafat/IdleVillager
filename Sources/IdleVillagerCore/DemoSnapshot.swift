import Foundation

extension SessionSnapshot {
    /// UI 開發與預覽用的示範快照：兩個 Workspace，3 個 Working、2 個 Needs Approval、1 個 Idle、1 個 Done。
    ///
    /// 內容是虛構資料，不代表 Herdr 實際送出的值。
    public static let demo: SessionSnapshot = {
        let updatedAt = Date(timeIntervalSince1970: 1_800_000_000)

        func session(
            _ id: String,
            workspace: (id: String, name: String),
            tab: (id: String, name: String),
            pane: (id: String, label: String),
            kind: String,
            displayName: String,
            rawState: String
        ) -> AgentSession {
            AgentSession(
                workspaceID: WorkspaceID(workspace.id),
                workspaceName: workspace.name,
                tabID: TabID(tab.id),
                tabName: tab.name,
                paneID: PaneID(pane.id),
                paneLabel: pane.label,
                agentSessionID: AgentSessionID(id),
                agentKind: kind,
                displayName: displayName,
                rawState: rawState,
                updatedAt: updatedAt,
                stateSource: .explicitEvent
            )
        }

        let backend = (id: "demo-ws-backend", name: "Backend Project")
        let frontend = (id: "demo-ws-frontend", name: "Frontend Project")
        let api = (id: "demo-tab-api", name: "API 開發")
        let tests = (id: "demo-tab-tests", name: "測試")
        let ui = (id: "demo-tab-ui", name: "UI 開發")

        return SessionSnapshot(sessions: [
            session("demo-1", workspace: backend, tab: api, pane: ("demo-pane-1", "Pane 1"), kind: "codex", displayName: "Codex", rawState: "working"),
            session("demo-2", workspace: backend, tab: api, pane: ("demo-pane-2", "Pane 2"), kind: "claude", displayName: "Claude Code", rawState: "waiting_for_approval"),
            session("demo-3", workspace: backend, tab: tests, pane: ("demo-pane-3", "Pane 1"), kind: "codex", displayName: "Codex", rawState: "idle"),
            session("demo-4", workspace: backend, tab: tests, pane: ("demo-pane-4", "Pane 2"), kind: "gemini", displayName: "Gemini CLI", rawState: "done"),
            session("demo-5", workspace: frontend, tab: ui, pane: ("demo-pane-5", "Pane 1"), kind: "claude", displayName: "Claude Code", rawState: "working"),
            session("demo-6", workspace: frontend, tab: ui, pane: ("demo-pane-6", "Pane 2"), kind: "claude", displayName: "Claude Code", rawState: "running"),
            session("demo-7", workspace: frontend, tab: ui, pane: ("demo-pane-7", "Pane 3"), kind: "gemini", displayName: "Gemini CLI", rawState: "needsApproval"),
        ])
    }()
}
