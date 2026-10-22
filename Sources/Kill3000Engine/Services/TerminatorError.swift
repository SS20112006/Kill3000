import Foundation

/// Typed domain errors for process termination operations.
public enum TerminatorError: Error, Sendable, Equatable, LocalizedError, CustomStringConvertible {
    /// Attempted to terminate a protected process (PID <= 1: kernel, current process group, or launchd).
    case protectedProcess(pid_t)

    /// Insufficient POSIX permissions to signal the target process (EPERM).
    case permissionDenied(pid_t)

    /// The target process does not exist or has already terminated (ESRCH).
    case processNotFound(pid_t)

    /// General termination failure with associated PID and POSIX errno or exit code.
    case terminationFailed(pid_t, Int32)

    public var errorDescription: String? {
        switch self {
        case .protectedProcess(let pid):
            return "Cannot terminate protected system process (PID \(pid))."
        case .permissionDenied(let pid):
            return "Insufficient permissions to terminate process (PID \(pid)). Process may belong to root or another user."
        case .processNotFound(let pid):
            return "Process (PID \(pid)) was not found or has already terminated."
        case .terminationFailed(let pid, let code):
            return "Failed to terminate process (PID \(pid)) with exit code \(code)."
        }
    }

    public var description: String {
        errorDescription ?? "Unknown termination error"
    }
}
