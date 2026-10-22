import Foundation
import Darwin
import Kill3000Engine

/// Command-line interface handler for Kill3000.
/// Provides terminal capabilities for headless environments, CI/CD smoke tests, and developer automation.
public struct CLIHandler: Sendable {
    public let scanner: any PortScanning
    public let terminator: any ProcessTerminating
    public let printOut: @Sendable (String) -> Void
    public let printErr: @Sendable (String) -> Void

    public init(
        scanner: any PortScanning = PortScanner(),
        terminator: any ProcessTerminating = ProcessTerminator(),
        printOut: @escaping @Sendable (String) -> Void = { print($0) },
        printErr: @escaping @Sendable (String) -> Void = { fputs("\($0)\n", Darwin.stderr) }
    ) {
        self.scanner = scanner
        self.terminator = terminator
        self.printOut = printOut
        self.printErr = printErr
    }

    /// Determines if the provided arguments contain CLI commands intended for terminal execution.
    public static func isCLIInvocation(arguments: [String] = CommandLine.arguments) -> Bool {
        let recognizedFlags: Set<String> = [
            "--scan", "-s",
            "--kill", "-k",
            "--version", "-v",
            "--help", "-h"
        ]
        return arguments.dropFirst().contains { recognizedFlags.contains($0) }
    }

    /// Executes the CLI command and returns the process exit code.
    public func execute(arguments: [String] = CommandLine.arguments) async -> Int32 {
        let args = Array(arguments.dropFirst())
        guard !args.isEmpty else {
            printHelp()
            return 0
        }

        if args.contains("--help") || args.contains("-h") {
            printHelp()
            return 0
        }

        if args.contains("--version") || args.contains("-v") {
            printOut("Kill3000 1.0.0")
            return 0
        }

        if args.contains("--scan") || args.contains("-s") {
            return await runScan()
        }

        if let killIndex = args.firstIndex(where: { $0 == "--kill" || $0 == "-k" }) {
            let nextIndex = killIndex + 1
            guard nextIndex < args.count, let portNumber = Int(args[nextIndex]), (1...65535).contains(portNumber) else {
                let invalidArg = nextIndex < args.count ? args[nextIndex] : ""
                printErr("Error: Invalid port number '\(invalidArg)'. Must be an integer between 1 and 65535.")
                return 1
            }
            return await runKill(port: portNumber)
        }

        printErr("Error: Unrecognized option '\(args.first ?? "")'. Run 'kill3000 --help' for usage.")
        return 1
    }

    private func runScan() async -> Int32 {
        do {
            let ports = try await scanner.scan()
            if ports.isEmpty {
                printOut("No listening TCP ports detected.")
                return 0
            }

            // Print table header
            let header = String(
                format: "%-7@ %-7@ %-16@ %-16@ %-12@ %@",
                "PORT", "PID", "PROCESS", "USER", "PROTOCOLS", "CATEGORY"
            )
            printOut(header)
            printOut(String(repeating: "-", count: 75))

            for port in ports {
                let protoStr = port.protocols.sorted().joined(separator: ", ")
                let row = String(
                    format: "%-7d %-7d %-16@ %-16@ %-12@ %@",
                    port.port,
                    port.pid,
                    port.processName,
                    port.user,
                    protoStr,
                    port.category.rawValue
                )
                printOut(row)
            }
            return 0
        } catch {
            printErr("Error scanning ports: \(error.localizedDescription)")
            return 1
        }
    }

    private func runKill(port targetPort: Int) async -> Int32 {
        do {
            let ports = try await scanner.scan()
            let matches = ports.filter { $0.port == targetPort }
            if matches.isEmpty {
                printErr("Error: No active listening process found on port \(targetPort).")
                return 1
            }

            for match in matches {
                try await terminator.terminate(port: match)
                printOut("Successfully terminated process '\(match.processName)' (PID \(match.pid)) on port \(targetPort).")
            }
            return 0
        } catch let err as TerminatorError {
            printErr("Error: \(err.localizedDescription)")
            return 1
        } catch {
            printErr("Error: \(error.localizedDescription)")
            return 1
        }
    }

    private func printHelp() {
        let helpText = """
        Kill3000 - Lightweight macOS Menu Bar Port Inspector & Process Terminator

        Usage:
          kill3000 [options]

        Options:
          -s, --scan              Scan and list all active listening TCP ports
          -k, --kill <port>       Terminate process listening on the specified port
          -v, --version           Print version information
          -h, --help              Print this help message

        When invoked without options, Kill3000 launches as a native macOS menu bar app.
        """
        printOut(helpText)
    }
}
