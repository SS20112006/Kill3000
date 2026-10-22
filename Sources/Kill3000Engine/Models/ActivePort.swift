import Foundation

/// Represents an active TCP listening port identified on the system.
public struct ActivePort: Identifiable, Sendable, Equatable, Hashable, Codable {
    /// Unique identifier composed of the port number and process PID.
    public var id: String {
        "\(port)-\(pid)"
    }

    /// The listening TCP port number.
    public let port: Int

    /// The Process ID (PID) holding the port.
    public let pid: pid_t

    /// The name of the process (e.g., "node", "vite", "python3").
    public let processName: String

    /// Optional executable or command path of the process.
    public let commandPath: String?

    /// Username owning the process.
    public let user: String

    /// Network protocols bound (e.g., ["IPv4"], ["IPv6"], or ["IPv4", "IPv6"]).
    public let protocols: Set<String>

    /// Category distinguishing development servers from system background daemons.
    public let category: ProcessCategory

    public init(
        port: Int,
        pid: pid_t,
        processName: String,
        commandPath: String? = nil,
        user: String,
        protocols: Set<String>,
        category: ProcessCategory
    ) {
        self.port = port
        self.pid = pid
        self.processName = processName
        self.commandPath = commandPath
        self.user = user
        self.protocols = protocols
        self.category = category
    }
}
