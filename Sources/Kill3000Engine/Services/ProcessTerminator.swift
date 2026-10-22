import Foundation
import Darwin

/// Service responsible for safely terminating processes associated with listening ports.
///
/// Implements safety barriers (protecting PID <= 1), graceful SIGTERM signaling with
/// liveness polling, and automatic escalation to SIGKILL if the process fails to exit within 1.5s.
public struct ProcessTerminator: Sendable {
    public typealias SignalSender = @Sendable (pid_t, Int32) -> Int32
    public typealias ErrnoProvider = @Sendable () -> Int32
    public typealias Sleeper = @Sendable (Duration) async throws -> Void

    private let signalSender: SignalSender
    private let getErrno: ErrnoProvider
    private let timeout: Duration
    private let checkInterval: Duration
    private let sleeper: Sleeper

    /// Default initializer using Darwin POSIX functions and system clock.
    ///
    /// - Parameters:
    ///   - timeout: Maximum duration to wait for graceful SIGTERM shutdown before escalating to SIGKILL (default: 1.5s).
    ///   - checkInterval: Polling interval for liveness verification (default: 50ms).
    public init(
        timeout: Duration = .milliseconds(1500),
        checkInterval: Duration = .milliseconds(50)
    ) {
        self.signalSender = Darwin.kill
        self.getErrno = { Darwin.errno }
        self.timeout = timeout
        self.checkInterval = checkInterval
        self.sleeper = { try await Task.sleep(for: $0) }
    }

    /// Internal initializer for dependency injection and deterministic unit testing.
    internal init(
        signalSender: @escaping SignalSender,
        getErrno: @escaping ErrnoProvider,
        timeout: Duration = .milliseconds(1500),
        checkInterval: Duration = .milliseconds(50),
        sleeper: @escaping Sleeper = { try await Task.sleep(for: $0) }
    ) {
        self.signalSender = signalSender
        self.getErrno = getErrno
        self.timeout = timeout
        self.checkInterval = checkInterval
        self.sleeper = sleeper
    }

    /// Static convenience method to terminate a process by PID.
    public static func terminate(pid: pid_t) async throws {
        try await ProcessTerminator().terminate(pid: pid)
    }

    /// Static convenience method to terminate the process associated with an `ActivePort`.
    public static func terminate(port: ActivePort) async throws {
        try await ProcessTerminator().terminate(pid: port.pid)
    }

    /// Terminates the process associated with an `ActivePort`.
    public func terminate(port: ActivePort) async throws {
        try await terminate(pid: port.pid)
    }

    /// Terminates a process by its PID using graceful SIGTERM followed by SIGKILL escalation.
    ///
    /// - Parameter pid: The target process ID. Must be strictly greater than 1.
    /// - Throws: `TerminatorError.protectedProcess` if PID <= 1,
    ///           `TerminatorError.processNotFound` if the process does not exist,
    ///           `TerminatorError.permissionDenied` if caller lacks privileges (EPERM),
    ///           `TerminatorError.terminationFailed` for other failures.
    public func terminate(pid: pid_t) async throws {
        // 1. Safety barrier: Protect PID 0, 1 (launchd), and negative process groups
        guard pid > 1 else {
            throw TerminatorError.protectedProcess(pid)
        }

        // 2. Issue initial SIGTERM for graceful shutdown
        let termStatus = signalSender(pid, SIGTERM)
        if termStatus != 0 {
            let err = getErrno()
            if err == ESRCH {
                throw TerminatorError.processNotFound(pid)
            } else if err == EPERM {
                throw TerminatorError.permissionDenied(pid)
            } else {
                throw TerminatorError.terminationFailed(pid, err)
            }
        }

        // 3. Check if process terminated immediately
        if !isProcessAlive(pid: pid) {
            return
        }

        // 4. Poll for termination during grace period (up to 1.5s)
        let clock = ContinuousClock()
        let start = clock.now

        while clock.now - start < timeout {
            try await sleeper(checkInterval)
            if !isProcessAlive(pid: pid) {
                return
            }
        }

        // 5. Escalate to SIGKILL if process still alive after timeout
        let killStatus = signalSender(pid, SIGKILL)
        if killStatus != 0 {
            let err = getErrno()
            if err == ESRCH {
                // Terminated just as SIGKILL was emitted
                return
            } else if err == EPERM {
                throw TerminatorError.permissionDenied(pid)
            } else {
                throw TerminatorError.terminationFailed(pid, err)
            }
        }

        // 6. Verify SIGKILL took effect
        if !isProcessAlive(pid: pid) {
            return
        }

        let killGracePeriod: Duration = .milliseconds(500)
        let killStart = clock.now
        while clock.now - killStart < killGracePeriod {
            try await sleeper(checkInterval)
            if !isProcessAlive(pid: pid) {
                return
            }
        }

        // If still alive after SIGKILL and grace period, report failure
        if isProcessAlive(pid: pid) {
            throw TerminatorError.terminationFailed(pid, -1)
        }
    }

    /// Checks if a process is alive using signal 0.
    private func isProcessAlive(pid: pid_t) -> Bool {
        if signalSender(pid, 0) == 0 {
            return true
        }
        let err = getErrno()
        if err == ESRCH {
            return false
        }
        // If EPERM, process still exists but belongs to another user
        return true
    }
}
