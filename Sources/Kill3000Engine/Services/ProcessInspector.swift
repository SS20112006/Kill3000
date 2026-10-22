import Foundation

/// Classifies processes into development tools or macOS system daemons.
public enum ProcessInspector: Sendable {
    /// Known macOS system daemons and background services.
    private static let systemDaemons: Set<String> = [
        "mdnsresponder",
        "mdnsrespo",
        "rapportd",
        "cupsd",
        "launchd",
        "controlcenter",
        "controlce",
        "identityservicesd",
        "identitys",
        "sharingd",
        "universalaccessd",
        "airplayxpchelper",
        "timed",
        "systemstatusd",
        "bluetoothd",
        "trustd",
        "distnoted",
        "coreauthd",
        "apsd",
        "audiomxd",
        "syslogd",
        "opendirectoryd",
        "configd",
        "loginwindow",
        "windowserver"
    ]

    /// Known development servers, runtimes, and tooling.
    private static let developmentTools: Set<String> = [
        "node",
        "vite",
        "bun",
        "deno",
        "next",
        "python",
        "python3",
        "go",
        "cargo",
        "rustc",
        "ruby",
        "docker-proxy",
        "docker-pr",
        "postgres",
        "redis-server",
        "redis-ser",
        "java",
        "php",
        "nginx",
        "caddy",
        "flask",
        "uvicorn",
        "gunicorn",
        "rails",
        "puma",
        "webpack",
        "esbuild",
        "mongod",
        "mysqld",
        "beam.smp",
        "elixir",
        "dotnet",
        "swift",
        "air",
        "turbopack"
    ]

    /// Classifies a process name into `.systemDaemon` or `.development`.
    ///
    /// - Parameter processName: The process or command name to inspect.
    /// - Returns: The classified `ProcessCategory`. Defaults to `.development`
    ///   so custom user servers are visible by default.
    public static func classify(processName: String) -> ProcessCategory {
        let normalized = processName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if systemDaemons.contains(normalized) {
            return .systemDaemon
        }

        if developmentTools.contains(normalized) {
            return .development
        }

        // Check common prefixes for versioned or truncated names
        if normalized.hasPrefix("python") ||
            normalized.hasPrefix("node") ||
            normalized.hasPrefix("ruby") ||
            normalized.hasPrefix("docker") {
            return .development
        }

        if normalized.hasPrefix("mdns") ||
            normalized.hasPrefix("rapport") ||
            normalized.hasPrefix("cups") {
            return .systemDaemon
        }

        // Unknown binaries default to development so developer custom servers are not hidden.
        return .development
    }
}

/// Semantic alias for `ProcessInspector`.
public typealias ProcessClassifier = ProcessInspector
