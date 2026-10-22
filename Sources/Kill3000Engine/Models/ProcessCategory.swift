import Foundation

/// Categorizes listening processes into development servers or macOS system daemons.
public enum ProcessCategory: String, Sendable, CaseIterable, Codable, Hashable {
    case development = "Dev Server"
    case systemDaemon = "macOS System"
}
