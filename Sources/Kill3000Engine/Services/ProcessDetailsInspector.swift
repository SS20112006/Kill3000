import Foundation
import Darwin

/// Contract for enriching `ActivePort` records with runtime metadata, CWD, framework identification,
/// and kill safety recommendations.
public protocol ProcessEnriching: Sendable {
    func enrich(ports: [ActivePort]) async -> [ActivePort]
}

/// Metadata extracted for a single running process.
public struct ProcessEnrichmentData: Sendable, Equatable {
    public let commandPath: String?
    public let projectOrAppName: String?
    public let workingDirectory: String?
    public let commandArgs: String?
    public let framework: String?
    public let uptimeSeconds: TimeInterval?
    public let parentPid: pid_t?
    public let isOrphan: Bool
    public let recommendation: KillRecommendation

    public init(
        commandPath: String? = nil,
        projectOrAppName: String? = nil,
        workingDirectory: String? = nil,
        commandArgs: String? = nil,
        framework: String? = nil,
        uptimeSeconds: TimeInterval? = nil,
        parentPid: pid_t? = nil,
        isOrphan: Bool = false,
        recommendation: KillRecommendation
    ) {
        self.commandPath = commandPath
        self.projectOrAppName = projectOrAppName
        self.workingDirectory = workingDirectory
        self.commandArgs = commandArgs
        self.framework = framework
        self.uptimeSeconds = uptimeSeconds
        self.parentPid = parentPid
        self.isOrphan = isOrphan
        self.recommendation = recommendation
    }
}

/// Inspects running processes via high-performance native Darwin kernel APIs (`libproc` and `sysctl`).
///
/// Features:
/// - In-process execution with zero subprocess forks, completing inspection in microseconds.
/// - Deterministic extraction of Current Working Directory (CWD) and manifest inspection (`package.json`, `Cargo.toml`).
/// - Detection of macOS application bundles (`.app`).
/// - Command line argument inspection and framework classification.
/// - Process lifecycle analysis (parent PID, orphan / zombie detection, and uptime calculation).
public struct ProcessDetailsInspector: ProcessEnriching, Sendable {

    /// Persistent local database or background service daemons that should not be classified as orphans.
    private static let persistentServiceBinaries: Set<String> = [
        "postgres",
        "redis-server",
        "redis-ser",
        "mongod",
        "mysqld",
        "docker-proxy",
        "docker-pr",
        "caddy",
        "nginx"
    ]

    public init() {}

    /// Enriches a collection of `ActivePort` records with deep process context.
    ///
    /// - Parameter ports: The active ports parsed from `lsof`.
    /// - Returns: Re-mapped `ActivePort` records containing enriched project, uptime, and safety metadata.
    public func enrich(ports: [ActivePort]) async -> [ActivePort] {
        ports.map { port in
            let details = inspect(
                pid: port.pid,
                port: port.port,
                processName: port.processName,
                category: port.category
            )

            return ActivePort(
                port: port.port,
                pid: port.pid,
                processName: port.processName,
                commandPath: details.commandPath ?? port.commandPath,
                user: port.user,
                protocols: port.protocols,
                category: port.category,
                projectOrAppName: details.projectOrAppName ?? port.projectOrAppName,
                workingDirectory: details.workingDirectory ?? port.workingDirectory,
                commandArgs: details.commandArgs ?? port.commandArgs,
                framework: details.framework ?? port.framework,
                uptimeSeconds: details.uptimeSeconds ?? port.uptimeSeconds,
                parentPid: details.parentPid ?? port.parentPid,
                isOrphan: details.isOrphan,
                recommendation: details.recommendation
            )
        }
    }

    /// Inspects a single process by PID and evaluates its working context.
    public func inspect(
        pid: pid_t,
        port: Int,
        processName: String,
        category: ProcessCategory
    ) -> ProcessEnrichmentData {
        let execPath = getExecutablePath(pid: pid)
        let cwd = getWorkingDirectory(pid: pid)
        let bsdInfo = getBsdInfo(pid: pid)
        let rawArgs = getCommandArgs(pid: pid)

        let appName = extractAppName(from: execPath)
        let projectName = appName ?? extractProjectName(fromCwd: cwd)

        let commandString = rawArgs?.joined(separator: " ")
        let framework = detectFramework(
            processName: processName,
            port: port,
            args: commandString,
            execPath: execPath,
            category: category
        )

        let parentPid = bsdInfo?.ppid
        let uptime = bsdInfo?.uptime

        let (isOrphan, recommendation) = evaluateRecommendation(
            pid: pid,
            parentPid: parentPid,
            processName: processName,
            category: category,
            uptime: uptime,
            isAppBundle: appName != nil
        )

        return ProcessEnrichmentData(
            commandPath: execPath,
            projectOrAppName: projectName,
            workingDirectory: cwd,
            commandArgs: commandString,
            framework: framework,
            uptimeSeconds: uptime,
            parentPid: parentPid,
            isOrphan: isOrphan,
            recommendation: recommendation
        )
    }

    // MARK: - Native Darwin Kernel Inspections

    /// Retrieves the executable path of the process via `proc_pidpath`.
    private func getExecutablePath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        let path = buffer.withUnsafeBufferPointer { ptr -> String in
            guard let base = ptr.baseAddress else { return "" }
            return String(cString: base)
        }.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    /// Retrieves the Current Working Directory (CWD) of the process via `proc_pidinfo(PROC_PIDVNODEPATHINFO)`.
    private func getWorkingDirectory(pid: pid_t) -> String? {
        var vpi = proc_vnodepathinfo()
        let size = proc_pidinfo(
            pid,
            PROC_PIDVNODEPATHINFO,
            0,
            &vpi,
            Int32(MemoryLayout<proc_vnodepathinfo>.size)
        )
        guard size > 0 else { return nil }

        let path = withUnsafeBytes(of: &vpi.pvi_cdir.vip_path) { rawPtr -> String in
            guard let base = rawPtr.baseAddress?.assumingMemoryBound(to: CChar.self) else { return "" }
            return String(cString: base)
        }.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !path.isEmpty && path != "/" else { return nil }
        return path
    }

    private struct BsdDetails {
        let ppid: pid_t
        let uptime: TimeInterval
    }

    /// Retrieves BSD process metadata (Parent PID and process uptime) via `proc_pidinfo(PROC_PIDTBSDINFO)`.
    private func getBsdInfo(pid: pid_t) -> BsdDetails? {
        var bsd = proc_bsdinfo()
        let size = proc_pidinfo(
            pid,
            PROC_PIDTBSDINFO,
            0,
            &bsd,
            Int32(MemoryLayout<proc_bsdinfo>.size)
        )
        guard size > 0 else { return nil }

        let ppid = pid_t(bsd.pbi_ppid)
        var uptime: TimeInterval = 0
        if bsd.pbi_start_tvsec > 0 {
            uptime = max(0, Date().timeIntervalSince1970 - Double(bsd.pbi_start_tvsec))
        }

        return BsdDetails(ppid: ppid, uptime: uptime)
    }

    /// Retrieves the process command-line arguments via `sysctl(KERN_PROCARGS2)`.
    private func getCommandArgs(pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: Int = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else {
            return nil
        }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else {
            return nil
        }

        return buffer.withUnsafeBytes { rawPtr -> [String]? in
            guard size >= MemoryLayout<Int32>.size else { return nil }
            let argc = rawPtr.load(as: Int32.self)
            guard argc > 0 else { return nil }

            var offset = MemoryLayout<Int32>.size

            // Skip executable path
            while offset < size && buffer[offset] != 0 { offset += 1 }
            // Skip null padding
            while offset < size && buffer[offset] == 0 { offset += 1 }

            var args: [String] = []
            for _ in 0..<argc {
                guard offset < size else { break }
                guard let base = rawPtr.baseAddress else { break }
                let strPtr = base.advanced(by: offset).assumingMemoryBound(to: CChar.self)
                let arg = String(cString: strPtr)
                args.append(arg)
                offset += arg.utf8.count + 1
            }
            return args.isEmpty ? nil : args
        }
    }

    // MARK: - Identification Helpers

    /// Extracts application name if binary resides inside a macOS `.app` bundle.
    private func extractAppName(from execPath: String?) -> String? {
        guard let path = execPath else { return nil }
        guard let range = path.range(of: ".app(/|$)", options: .regularExpression) else { return nil }

        let prefix = path[..<range.lowerBound]
        if let lastSlash = prefix.lastIndex(of: "/") {
            return String(prefix[prefix.index(after: lastSlash)...])
        }
        return String(prefix)
    }

    /// Extracts project name from working directory by reading manifest or directory basename.
    private func extractProjectName(fromCwd cwd: String?) -> String? {
        guard let directory = cwd, !directory.isEmpty, directory != "/" else { return nil }

        // Check for package.json
        let packageJsonPath = (directory as NSString).appendingPathComponent("package.json")
        if let data = try? Data(contentsOf: URL(fileURLWithPath: packageJsonPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let name = json["name"] as? String, !name.isEmpty {
            return name
        }

        // Check for Cargo.toml
        let cargoPath = (directory as NSString).appendingPathComponent("Cargo.toml")
        if let contents = try? String(contentsOfFile: cargoPath, encoding: .utf8),
           let match = contents.range(of: #"name\s*=\s*\"([^\"]+)\""#, options: .regularExpression) {
            let line = String(contents[match])
            if let start = line.firstIndex(of: "\""), let end = line.lastIndex(of: "\""), start != end {
                let name = String(line[line.index(after: start)..<end])
                if !name.isEmpty { return name }
            }
        }

        // Fallback to directory basename
        let basename = (directory as NSString).lastPathComponent
        return basename.isEmpty ? nil : basename
    }

    /// Detects high-level framework or tool name based on arguments, binary path, and well-known ports.
    private func detectFramework(
        processName: String,
        port: Int,
        args: String?,
        execPath: String?,
        category: ProcessCategory
    ) -> String? {
        let text = "\(processName) \(args ?? "") \(execPath ?? "")".lowercased()

        // 1. Web Frameworks & Dev Servers
        if text.contains("next") {
            return "Next.js"
        } else if text.contains("vite") {
            return "Vite"
        } else if text.contains("nuxt") {
            return "Nuxt"
        } else if text.contains("astro") {
            return "Astro"
        } else if text.contains("remix") {
            return "Remix"
        } else if text.contains("webpack") {
            return "Webpack"
        } else if text.contains("turbopack") {
            return "Turbopack"
        } else if text.contains("uvicorn") || text.contains("fastapi") {
            return "FastAPI"
        } else if text.contains("manage.py") || text.contains("django") {
            return "Django"
        } else if text.contains("flask") {
            return "Flask"
        } else if text.contains("rails") {
            return "Rails"
        } else if text.contains("puma") {
            return "Puma"
        } else if text.contains("http.server") {
            return "Python HTTP"
        } else if text.contains("redis-server") {
            return "Redis"
        } else if text.contains("postgres") {
            return "PostgreSQL"
        } else if text.contains("mongod") {
            return "MongoDB"
        } else if text.contains("mysqld") {
            return "MySQL"
        } else if text.contains("docker") {
            return "Docker"
        }

        // 2. macOS System Features
        if category == .systemDaemon {
            if port == 5000 || port == 7000 {
                return "AirPlay Receiver"
            }
            if processName.lowercased().contains("rapport") {
                return "Continuity / AirDrop"
            }
            if processName.lowercased().contains("mdns") {
                return "Bonjour / mDNS"
            }
        }

        // 3. Well-known standard port fallbacks
        switch port {
        case 3000:
            return "Web Server (:3000)"
        case 5173:
            return "Vite (:5173)"
        case 8000:
            return "API Server (:8000)"
        case 8080:
            return "HTTP Server (:8080)"
        case 5432:
            return "PostgreSQL"
        case 6379:
            return "Redis"
        case 27017:
            return "MongoDB"
        case 3306:
            return "MySQL"
        default:
            return nil
        }
    }

    /// Evaluates whether a process is an orphan and formulates a cleanup recommendation.
    private func evaluateRecommendation(
        pid: pid_t,
        parentPid: pid_t?,
        processName: String,
        category: ProcessCategory,
        uptime: TimeInterval?,
        isAppBundle: Bool = false
    ) -> (isOrphan: Bool, recommendation: KillRecommendation) {
        if category == .systemDaemon {
            return (false, .systemProtected(reason: "Serviço essencial do macOS"))
        }

        let normalizedName = processName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Persistent database engines
        if Self.persistentServiceBinaries.contains(normalizedName) {
            return (false, .active(reason: "Base de dados ou serviço em background"))
        }

        // GUI Application Bundles (.app) are launched under launchd (PID 1) by normal macOS design
        if isAppBundle {
            return (false, .active(reason: "Aplicação macOS ativa"))
        }

        // Orphan detection: PPID == 1 indicates parent (e.g. terminal / IDE) died and process was reparented to launchd
        if let parent = parentPid {
            if parent == 1 {
                return (true, .recommended(reason: "Processo órfão (terminal ou editor pai foi fechado)"))
            }

            // Check if parent PID is still alive
            var isParentAlive = true
            if kill(parent, 0) != 0 && errno == ESRCH {
                isParentAlive = false
            }

            if !isParentAlive {
                return (true, .recommended(reason: "Processo pai já não se encontra em execução"))
            }
        }

        // Idle dev servers running longer than 24 hours
        if let seconds = uptime, seconds > 86400 {
            return (false, .recommended(reason: "Servidor inativo há mais de 24h"))
        }

        return (false, .active(reason: "Sessão de desenvolvimento ativa"))
    }
}
