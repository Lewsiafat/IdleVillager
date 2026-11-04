/// Herdr 提供的 Workspace 穩定識別碼。不可用列表序號或名稱替代。
public struct WorkspaceID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

/// Herdr 提供的 Tab 穩定識別碼。
public struct TabID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

/// Herdr 提供的 Pane 穩定識別碼。
public struct PaneID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

/// Agent Session 的穩定識別碼，也是 Session Store 的主鍵。
public struct AgentSessionID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}
