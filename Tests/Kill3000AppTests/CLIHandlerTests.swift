import XCTest
@testable import Kill3000Engine
@testable import Kill3000App

final class CLIHandlerTests: XCTestCase {

    // MARK: - Mocks

    final class MockScanner: PortScanning, @unchecked Sendable {
        var portsToReturn: [ActivePort]
        var shouldThrow: Error?

        init(portsToReturn: [ActivePort] = [], shouldThrow: Error? = nil) {
            self.portsToReturn = portsToReturn
            self.shouldThrow = shouldThrow
        }

        func scan() async throws -> [ActivePort] {
            if let shouldThrow {
                throw shouldThrow
            }
            return portsToReturn
        }
    }

    final class MockTerminator: ProcessTerminating, @unchecked Sendable {
        var terminatedPorts: [ActivePort] = []
        var terminatedPids: [pid_t] = []
        var shouldThrow: Error?

        init(shouldThrow: Error? = nil) {
            self.shouldThrow = shouldThrow
        }

        func terminate(port: ActivePort) async throws {
            if let shouldThrow {
                throw shouldThrow
            }
            terminatedPorts.append(port)
            terminatedPids.append(port.pid)
        }

        func terminate(pid: pid_t) async throws {
            if let shouldThrow {
                throw shouldThrow
            }
            terminatedPids.append(pid)
        }
    }

    final class OutputCapture: @unchecked Sendable {
        var stdoutLines: [String] = []
        var stderrLines: [String] = []

        func printOut(_ text: String) {
            stdoutLines.append(text)
        }

        func printErr(_ text: String) {
            stderrLines.append(text)
        }
    }

    // MARK: - Invocation Detection Tests

    func testIsCLIInvocationFlags() {
        XCTAssertTrue(CLIHandler.isCLIInvocation(arguments: ["kill3000", "--help"]))
        XCTAssertTrue(CLIHandler.isCLIInvocation(arguments: ["kill3000", "-h"]))
        XCTAssertTrue(CLIHandler.isCLIInvocation(arguments: ["kill3000", "--version"]))
        XCTAssertTrue(CLIHandler.isCLIInvocation(arguments: ["kill3000", "-v"]))
        XCTAssertTrue(CLIHandler.isCLIInvocation(arguments: ["kill3000", "--scan"]))
        XCTAssertTrue(CLIHandler.isCLIInvocation(arguments: ["kill3000", "-s"]))
        XCTAssertTrue(CLIHandler.isCLIInvocation(arguments: ["kill3000", "--kill", "3000"]))
        XCTAssertTrue(CLIHandler.isCLIInvocation(arguments: ["kill3000", "-k", "3000"]))

        // Normal GUI app launches or XCTest runner launches
        XCTAssertFalse(CLIHandler.isCLIInvocation(arguments: ["kill3000"]))
        XCTAssertFalse(CLIHandler.isCLIInvocation(arguments: ["kill3000", "-psn_0_12345"]))
        XCTAssertFalse(CLIHandler.isCLIInvocation(arguments: ["xctest", "-XCTest", "All"]))
    }

    // MARK: - Help and Version Tests

    func testHelpCommand() async {
        let capture = OutputCapture()
        let handler = CLIHandler(
            printOut: { capture.printOut($0) },
            printErr: { capture.printErr($0) }
        )

        let code = await handler.execute(arguments: ["kill3000", "--help"])
        XCTAssertEqual(code, 0)
        XCTAssertTrue(capture.stdoutLines.joined().contains("Usage:"))
        XCTAssertTrue(capture.stdoutLines.joined().contains("--scan"))
        XCTAssertTrue(capture.stdoutLines.joined().contains("--kill"))
        XCTAssertTrue(capture.stderrLines.isEmpty)
    }

    func testVersionCommand() async {
        let capture = OutputCapture()
        let handler = CLIHandler(
            printOut: { capture.printOut($0) },
            printErr: { capture.printErr($0) }
        )

        let code = await handler.execute(arguments: ["kill3000", "--version"])
        XCTAssertEqual(code, 0)
        XCTAssertEqual(capture.stdoutLines, ["Kill3000 1.0.0"])
        XCTAssertTrue(capture.stderrLines.isEmpty)
    }

    // MARK: - Scan Command Tests

    func testScanCommandWithNoActivePorts() async {
        let capture = OutputCapture()
        let scanner = MockScanner(portsToReturn: [])
        let handler = CLIHandler(
            scanner: scanner,
            printOut: { capture.printOut($0) },
            printErr: { capture.printErr($0) }
        )

        let code = await handler.execute(arguments: ["kill3000", "--scan"])
        XCTAssertEqual(code, 0)
        XCTAssertEqual(capture.stdoutLines, ["No listening TCP ports detected."])
        XCTAssertTrue(capture.stderrLines.isEmpty)
    }

    func testScanCommandWithActivePorts() async {
        let capture = OutputCapture()
        let samplePort = ActivePort(
            port: 3000,
            pid: 12345,
            processName: "node",
            user: "developer",
            protocols: ["IPv4", "IPv6"],
            category: .development
        )
        let scanner = MockScanner(portsToReturn: [samplePort])
        let handler = CLIHandler(
            scanner: scanner,
            printOut: { capture.printOut($0) },
            printErr: { capture.printErr($0) }
        )

        let code = await handler.execute(arguments: ["kill3000", "-s"])
        XCTAssertEqual(code, 0)
        XCTAssertEqual(capture.stdoutLines.count, 3) // Header, separator, row
        XCTAssertTrue(capture.stdoutLines[0].contains("PORT"))
        XCTAssertTrue(capture.stdoutLines[2].contains("3000"))
        XCTAssertTrue(capture.stdoutLines[2].contains("node"))
        XCTAssertTrue(capture.stdoutLines[2].contains("12345"))
        XCTAssertTrue(capture.stderrLines.isEmpty)
    }

    func testScanCommandFailure() async {
        let capture = OutputCapture()
        let scanner = MockScanner(shouldThrow: TerminatorError.permissionDenied(500))
        let handler = CLIHandler(
            scanner: scanner,
            printOut: { capture.printOut($0) },
            printErr: { capture.printErr($0) }
        )

        let code = await handler.execute(arguments: ["kill3000", "--scan"])
        XCTAssertEqual(code, 1)
        XCTAssertTrue(capture.stdoutLines.isEmpty)
        XCTAssertFalse(capture.stderrLines.isEmpty)
        XCTAssertTrue(capture.stderrLines[0].contains("Error scanning ports"))
    }

    // MARK: - Kill Command Tests

    func testKillCommandMissingPortArgument() async {
        let capture = OutputCapture()
        let handler = CLIHandler(
            printOut: { capture.printOut($0) },
            printErr: { capture.printErr($0) }
        )

        let code = await handler.execute(arguments: ["kill3000", "--kill"])
        XCTAssertEqual(code, 1)
        XCTAssertTrue(capture.stderrLines[0].contains("Invalid port number"))
    }

    func testKillCommandInvalidPortArgument() async {
        let capture = OutputCapture()
        let handler = CLIHandler(
            printOut: { capture.printOut($0) },
            printErr: { capture.printErr($0) }
        )

        let code = await handler.execute(arguments: ["kill3000", "-k", "invalid-port"])
        XCTAssertEqual(code, 1)
        XCTAssertTrue(capture.stderrLines[0].contains("Invalid port number 'invalid-port'"))
    }

    func testKillCommandPortOutOfRange() async {
        let capture = OutputCapture()
        let handler = CLIHandler(
            printOut: { capture.printOut($0) },
            printErr: { capture.printErr($0) }
        )

        let code = await handler.execute(arguments: ["kill3000", "--kill", "70000"])
        XCTAssertEqual(code, 1)
        XCTAssertTrue(capture.stderrLines[0].contains("Invalid port number '70000'"))
    }

    func testKillCommandPortNotFound() async {
        let capture = OutputCapture()
        let scanner = MockScanner(portsToReturn: [])
        let terminator = MockTerminator()
        let handler = CLIHandler(
            scanner: scanner,
            terminator: terminator,
            printOut: { capture.printOut($0) },
            printErr: { capture.printErr($0) }
        )

        let code = await handler.execute(arguments: ["kill3000", "--kill", "8080"])
        XCTAssertEqual(code, 1)
        XCTAssertEqual(capture.stderrLines, ["Error: No active listening process found on port 8080."])
        XCTAssertTrue(terminator.terminatedPorts.isEmpty)
    }

    func testKillCommandSuccess() async {
        let capture = OutputCapture()
        let targetPort = ActivePort(
            port: 3000,
            pid: 9876,
            processName: "vite",
            user: "developer",
            protocols: ["IPv4"],
            category: .development
        )
        let scanner = MockScanner(portsToReturn: [targetPort])
        let terminator = MockTerminator()
        let handler = CLIHandler(
            scanner: scanner,
            terminator: terminator,
            printOut: { capture.printOut($0) },
            printErr: { capture.printErr($0) }
        )

        let code = await handler.execute(arguments: ["kill3000", "--kill", "3000"])
        XCTAssertEqual(code, 0)
        XCTAssertEqual(terminator.terminatedPorts.count, 1)
        XCTAssertEqual(terminator.terminatedPorts[0].pid, 9876)
        XCTAssertTrue(capture.stdoutLines[0].contains("Successfully terminated process 'vite' (PID 9876) on port 3000."))
        XCTAssertTrue(capture.stderrLines.isEmpty)
    }

    func testKillCommandProtectedProcessError() async {
        let capture = OutputCapture()
        let targetPort = ActivePort(
            port: 80,
            pid: 1,
            processName: "launchd",
            user: "root",
            protocols: ["IPv4"],
            category: .systemDaemon
        )
        let scanner = MockScanner(portsToReturn: [targetPort])
        let terminator = MockTerminator(shouldThrow: TerminatorError.protectedProcess(1))
        let handler = CLIHandler(
            scanner: scanner,
            terminator: terminator,
            printOut: { capture.printOut($0) },
            printErr: { capture.printErr($0) }
        )

        let code = await handler.execute(arguments: ["kill3000", "--kill", "80"])
        XCTAssertEqual(code, 1)
        XCTAssertFalse(capture.stderrLines.isEmpty)
        XCTAssertTrue(capture.stderrLines[0].contains("protected system process"))
    }
}
