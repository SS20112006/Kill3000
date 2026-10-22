import XCTest
import Darwin
@testable import Kill3000Engine

final class ProcessTerminatorTests: XCTestCase {

    // MARK: - Safety Guard Tests

    func testProtectedProcessSafetyGuard() async {
        let terminator = ProcessTerminator()

        // PID 0 (kernel / current process group)
        do {
            try await terminator.terminate(pid: 0)
            XCTFail("Expected TerminatorError.protectedProcess for PID 0")
        } catch let error as TerminatorError {
            XCTAssertEqual(error, TerminatorError.protectedProcess(0))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // PID 1 (launchd / init)
        do {
            try await terminator.terminate(pid: 1)
            XCTFail("Expected TerminatorError.protectedProcess for PID 1")
        } catch let error as TerminatorError {
            XCTAssertEqual(error, TerminatorError.protectedProcess(1))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Negative PID
        do {
            try await terminator.terminate(pid: -5)
            XCTFail("Expected TerminatorError.protectedProcess for negative PID")
        } catch let error as TerminatorError {
            XCTAssertEqual(error, TerminatorError.protectedProcess(-5))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTerminateActivePortOverload() async {
        let port = ActivePort(
            port: 80,
            pid: 1,
            processName: "launchd",
            user: "root",
            protocols: ["IPv4"],
            category: .systemDaemon
        )

        do {
            try await ProcessTerminator.terminate(port: port)
            XCTFail("Expected TerminatorError.protectedProcess for PID 1 via ActivePort")
        } catch let error as TerminatorError {
            XCTAssertEqual(error, TerminatorError.protectedProcess(1))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Simulated Error Mapping Tests

    func testProcessNotFoundMapping() async {
        let terminator = ProcessTerminator(
            signalSender: { _, _ in -1 },
            getErrno: { ESRCH },
            timeout: .milliseconds(50),
            checkInterval: .milliseconds(10),
            sleeper: { _ in }
        )

        do {
            try await terminator.terminate(pid: 4242)
            XCTFail("Expected TerminatorError.processNotFound")
        } catch let error as TerminatorError {
            XCTAssertEqual(error, TerminatorError.processNotFound(4242))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPermissionDeniedMapping() async {
        let terminator = ProcessTerminator(
            signalSender: { _, _ in -1 },
            getErrno: { EPERM },
            timeout: .milliseconds(50),
            checkInterval: .milliseconds(10),
            sleeper: { _ in }
        )

        do {
            try await terminator.terminate(pid: 5000)
            XCTFail("Expected TerminatorError.permissionDenied")
        } catch let error as TerminatorError {
            XCTAssertEqual(error, TerminatorError.permissionDenied(5000))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTerminationFailedMapping() async {
        let terminator = ProcessTerminator(
            signalSender: { _, _ in -1 },
            getErrno: { EINVAL },
            timeout: .milliseconds(50),
            checkInterval: .milliseconds(10),
            sleeper: { _ in }
        )

        do {
            try await terminator.terminate(pid: 6000)
            XCTFail("Expected TerminatorError.terminationFailed")
        } catch let error as TerminatorError {
            XCTAssertEqual(error, TerminatorError.terminationFailed(6000, EINVAL))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Graceful SIGTERM vs Escalation Tests

    final class MockSignalState: @unchecked Sendable {
        var signalsSent: [(pid: pid_t, sig: Int32)] = []
        var checksCount: Int = 0
        var aliveAfterChecks: Int
        var killedWithSigkill: Bool = false

        init(aliveAfterChecks: Int) {
            self.aliveAfterChecks = aliveAfterChecks
        }
    }

    func testGracefulSigtermTerminationWithoutSigkill() async throws {
        let state = MockSignalState(aliveAfterChecks: 2)

        let terminator = ProcessTerminator(
            signalSender: { pid, sig in
                state.signalsSent.append((pid: pid, sig: sig))
                if sig == 0 {
                    state.checksCount += 1
                    if state.checksCount >= state.aliveAfterChecks {
                        // Process died
                        return -1
                    }
                    return 0 // Still alive
                }
                return 0 // Signal succeeded
            },
            getErrno: {
                // If checking liveness and returned -1, errno is ESRCH
                ESRCH
            },
            timeout: .milliseconds(500),
            checkInterval: .milliseconds(10),
            sleeper: { _ in }
        )

        try await terminator.terminate(pid: 1234)

        // Only SIGTERM and probe signals (0) should have been sent, NO SIGKILL
        let sigkillSent = state.signalsSent.contains { $0.sig == SIGKILL }
        XCTAssertFalse(sigkillSent, "SIGKILL should not be sent if process exits on SIGTERM")

        let sigtermSent = state.signalsSent.contains { $0.sig == SIGTERM }
        XCTAssertTrue(sigtermSent, "SIGTERM must be sent first")
    }

    func testEscalationToSigkillWhenProcessHangs() async throws {
        let state = MockSignalState(aliveAfterChecks: 999) // Never exits on its own

        let terminator = ProcessTerminator(
            signalSender: { pid, sig in
                state.signalsSent.append((pid: pid, sig: sig))
                if sig == SIGKILL {
                    state.killedWithSigkill = true
                    return 0
                }
                if sig == 0 {
                    if state.killedWithSigkill {
                        // After SIGKILL, it finally dies
                        return -1
                    }
                    return 0 // Still alive
                }
                return 0
            },
            getErrno: {
                ESRCH
            },
            timeout: .milliseconds(40),
            checkInterval: .milliseconds(10),
            sleeper: { _ in }
        )

        try await terminator.terminate(pid: 4321)

        let sigtermSent = state.signalsSent.contains { $0.sig == SIGTERM }
        let sigkillSent = state.signalsSent.contains { $0.sig == SIGKILL }

        XCTAssertTrue(sigtermSent, "SIGTERM must be sent first")
        XCTAssertTrue(sigkillSent, "SIGKILL must be escalated to when SIGTERM times out")
    }

    // MARK: - Error Descriptions & Path Masking

    func testTerminatorErrorFormattingAndSanitization() {
        let errors: [TerminatorError] = [
            .protectedProcess(1),
            .permissionDenied(500),
            .processNotFound(9999),
            .terminationFailed(1234, 1)
        ]

        for error in errors {
            let message = error.localizedDescription
            XCTAssertFalse(message.isEmpty)
            // Ensure no filesystem paths are leaked
            XCTAssertFalse(message.contains("at /"), "Error message should not leak file paths: \(message)")
            XCTAssertFalse(message.contains(".swift"), "Error message should not leak source filenames: \(message)")
        }
    }

    // MARK: - Real Process End-to-End Test

    func testRealProcessTermination() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["60"]
        try process.run()

        let pid = process.processIdentifier
        XCTAssertGreaterThan(pid, 1)

        // Verify it is alive
        XCTAssertEqual(Darwin.kill(pid, 0), 0)

        // Terminate using ProcessTerminator
        try await ProcessTerminator.terminate(pid: pid)

        // Verify it is dead
        process.waitUntilExit()
        XCTAssertFalse(process.isRunning)
        XCTAssertEqual(Darwin.kill(pid, 0), -1)
        XCTAssertEqual(Darwin.errno, ESRCH)
    }
}
