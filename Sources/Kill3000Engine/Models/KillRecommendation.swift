import Foundation

/// Actionable recommendation regarding whether an active port process should be terminated or preserved.
public enum KillRecommendation: Sendable, Equatable, Hashable, Codable {
    /// Safe and recommended to terminate (e.g., orphan process whose parent terminal exited, or abandoned server).
    case recommended(reason: String)

    /// Currently active and in use by the developer or another interactive tool.
    case active(reason: String)

    /// macOS system daemon or critical background service; should not be killed casually.
    case systemProtected(reason: String)

    /// Human-readable label for UI badge display.
    public var badgeLabel: String {
        switch self {
        case .recommended(let reason):
            if reason.lowercased().contains("órfão") || reason.lowercased().contains("orphan") {
                return "Órfão"
            } else if reason.lowercased().contains("24h") || reason.lowercased().contains("inativo") || reason.lowercased().contains("idle") {
                return "Inativo"
            }
            return "Limpar"
        case .active(let reason):
            if reason.lowercased().contains("database") || reason.lowercased().contains("dados") {
                return "DB"
            }
            return "Ativo"
        case .systemProtected:
            return "Sistema"
        }
    }

    /// Full descriptive reason explaining the recommendation.
    public var reasonDescription: String {
        switch self {
        case .recommended(let reason):
            return reason
        case .active(let reason):
            return reason
        case .systemProtected(let reason):
            return reason
        }
    }

    /// Indicates whether the recommendation explicitly suggests cleaning up the process.
    public var isRecommendedToKill: Bool {
        if case .recommended = self {
            return true
        }
        return false
    }
}
