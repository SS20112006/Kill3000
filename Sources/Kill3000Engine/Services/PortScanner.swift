import Foundation

/// Actor responsible for asynchronously inspecting listening TCP ports via macOS `lsof`.
///
/// Executes the process off the Swift Concurrency cooperative thread pool to guarantee
/// non-blocking I/O and zero latency spikes on the `@MainActor`.
public actor PortScanner {
    public typealias CommandRunner = @Sendable () async throws -> String

    private let runner: CommandRunner

    /// Initializes a `PortScanner` pointing to the system's `lsof` utility.
    /// - Parameter lsofPath: Path to the `lsof` executable. Defaults to `/usr/sbin/lsof`.
    public init(lsofPath: String = "/usr/sbin/lsof") {
        self.init(runner: {
            try await Self.runLsof(executablePath: lsofPath)
        })
    }

    /// Internal initializer allowing command runner injection for testing.
    internal init(runner: @escaping CommandRunner) {
        self.runner = runner
    }

    /// Asynchronously executes the port scan and returns detected active ports.
    ///
    /// - Returns: A list of `ActivePort` records deduplicated and sorted ascending by port.
    public func scan() async throws -> [ActivePort] {
        let output = try await runner()
        return PortParser.parse(output)
    }

    /// Executes `lsof` off the Swift Concurrency cooperative thread pool.
    private static func runLsof(executablePath: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()

                    process.executableURL = URL(fileURLWithPath: executablePath)
                    process.arguments = ["-iTCP", "-sTCP:LISTEN", "-n", "-P"]
                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe

                    try process.run()
                    let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    let status = process.terminationStatus
                    // lsof exits with 0 on match, and 1 when no sockets match
                    if status == 0 || status == 1 {
                        let output = String(data: data, encoding: .utf8) ?? ""
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(
                            throwing: TerminatorError.terminationFailed(
                                process.processIdentifier,
                                status
                            )
                        )
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
