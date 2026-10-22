import Foundation

/// Represents an active TCP listening port identified on the system, enriched with
/// project context, framework detection, uptime, and actionable cleanup recommendations.
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

    /// The detected project name (from package.json / directory name) or parent App bundle name.
    public let projectOrAppName: String?

    /// The current working directory (CWD) of the process, if discoverable.
    public let workingDirectory: String?

    /// Full command line arguments of the process.
    public let commandArgs: String?

    /// Detected framework or server tool (e.g., "Next.js", "Vite", "FastAPI", "PostgreSQL", "AirPlay").
    public let framework: String?

    /// Elapsed time in seconds since the process was spawned.
    public let uptimeSeconds: TimeInterval?

    /// The Process ID (PID) of the parent process.
    public let parentPid: pid_t?

    /// Indicates whether this process is an orphan (e.g. parent terminal/editor closed).
    public let isOrphan: Bool

    /// Actionable recommendation on whether to terminate or preserve this process.
    public let recommendation: KillRecommendation

    /// Indicates whether this port was spawned directly by the user (local dev server, CLI script, or project)
    /// rather than a macOS system daemon or background desktop application bundle (.app).
    public let isUserCreated: Bool

    public init(
        port: Int,
        pid: pid_t,
        processName: String,
        commandPath: String? = nil,
        user: String,
        protocols: Set<String>,
        category: ProcessCategory,
        projectOrAppName: String? = nil,
        workingDirectory: String? = nil,
        commandArgs: String? = nil,
        framework: String? = nil,
        uptimeSeconds: TimeInterval? = nil,
        parentPid: pid_t? = nil,
        isOrphan: Bool = false,
        recommendation: KillRecommendation? = nil,
        isUserCreated: Bool? = nil
    ) {
        self.port = port
        self.pid = pid
        self.processName = processName
        self.commandPath = commandPath
        self.user = user
        self.protocols = protocols
        self.category = category
        self.projectOrAppName = projectOrAppName
        self.workingDirectory = workingDirectory
        self.commandArgs = commandArgs
        self.framework = framework
        self.uptimeSeconds = uptimeSeconds
        self.parentPid = parentPid
        self.isOrphan = isOrphan

        if let explicit = isUserCreated {
            self.isUserCreated = explicit
        } else {
            let isApp = (commandPath?.contains(".app/") == true) ||
                        (commandPath?.hasPrefix("/Applications/") == true) ||
                        (workingDirectory?.contains(".app/") == true)
            self.isUserCreated = (category == .development) && !isApp
        }

        if let explicitRecommendation = recommendation {
            self.recommendation = explicitRecommendation
        } else if category == .systemDaemon {
            self.recommendation = .systemProtected(reason: "macOS System Service")
        } else if isOrphan {
            self.recommendation = .recommended(reason: "Processo órfão (terminal pai encerrado)")
        } else if let seconds = uptimeSeconds, seconds > 86400 {
            self.recommendation = .recommended(reason: "Servidor inativo há mais de 24h")
        } else {
            self.recommendation = .active(reason: "Sessão de desenvolvimento ativa")
        }
    }

    /// Human-friendly relative uptime string (e.g., "< 1m", "15m", "3h", "2d").
    public var formattedUptime: String? {
        guard let seconds = uptimeSeconds, seconds >= 0 else { return nil }
        if seconds < 60 {
            return "< 1m"
        } else if seconds < 3600 {
            let mins = Int(seconds / 60)
            return "\(mins)m"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours)h"
        } else {
            let days = Int(seconds / 86400)
            return "\(days)d"
        }
    }

    /// Primary display title combining detected framework, app name, or process name.
    public var displayTitle: String {
        if let framework = framework, !framework.isEmpty {
            if let project = projectOrAppName, !project.isEmpty,
               project.lowercased() != framework.lowercased(),
               !framework.lowercased().contains(project.lowercased()) {
                return "\(framework) • \(project)"
            }
            return framework
        }
        if let project = projectOrAppName, !project.isEmpty {
            if processName.lowercased() == project.lowercased() ||
               project.lowercased().hasPrefix(processName.lowercased()) {
                return project
            }
            return "\(project) (\(processName))"
        }
        return processName
    }

    /// Abbreviates the working directory path with `~` for cleaner UI presentation.
    public var abbreviatedPath: String? {
        guard let cwd = workingDirectory, !cwd.isEmpty, cwd != "/" else { return nil }
        let home = NSHomeDirectory()
        if cwd == home {
            return "~"
        } else if cwd.hasPrefix(home + "/") {
            return "~" + cwd.dropFirst(home.count)
        }
        return cwd
    }

    /// Basename of the working directory (e.g. "my-project" from "/Users/dev/my-project").
    public var workingDirectoryBasename: String? {
        guard let cwd = workingDirectory, !cwd.isEmpty, cwd != "/" else { return nil }
        let basename = (cwd as NSString).lastPathComponent
        return basename.isEmpty || basename == "/" ? nil : basename
    }

    /// Single-line compact subtitle showing PID, uptime, and folder without visual crowding.
    public var compactSubtitle: String {
        var parts: [String] = ["PID \(pid)"]
        if let uptime = formattedUptime {
            parts.append(uptime)
        }
        if let folder = workingDirectoryBasename,
           !displayTitle.lowercased().contains(folder.lowercased()) {
            parts.append(folder)
        }
        return parts.joined(separator: " • ")
    }
}
