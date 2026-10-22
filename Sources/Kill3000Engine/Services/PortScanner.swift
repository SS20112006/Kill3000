import Foundation

/// Protocol defining the contract for discovering active listening TCP ports.
public protocol PortScanning: Sendable {
    func scan() async throws -> [ActivePort]
}

/// Actor responsible for asynchronously inspecting listening TCP ports via macOS `lsof`
/// and enriching them with process details, project identification, uptime, and cleanup safety.
///
/// Executes the process off the Swift Concurrency cooperative thread pool to guarantee
/// non-blocking I/O and zero latency spikes on the `@MainActor`.
public actor PortScanner: PortScanning {
    public typealias CommandRunner = @Sendable () async throws -> String

    private let runner: CommandRunner
    private let enricher: any ProcessEnriching

    /// Initializes a `PortScanner` pointing to the system's `lsof` utility.
    /// - Parameters:
    ///   - lsofPath: Path to the `lsof` executable. Defaults to `/usr/sbin/lsof`.
    ///   - enricher: Service enriching ports with process metadata and recommendations.
    public init(
        lsofPath: String = "/usr/sbin/lsof",
        enricher: any ProcessEnriching = ProcessDetailsInspector()
    ) {
        self.init(
            runner: {
                try await Self.runLsof(executablePath: lsofPath)
            },
            enricher: enricher
        )
    }

    /// Internal initializer allowing command runner and enricher injection for testing.
    internal init(
        runner: @escaping CommandRunner,
        enricher: any ProcessEnriching = ProcessDetailsInspector()
    ) {
        self.runner = runner
        self.enricher = enricher
    }

    /// Asynchronously executes the port scan, parses outputs, and enriches records.
    ///
    /// - Returns: A list of enriched `ActivePort` records deduplicated and sorted ascending by port.
    public func scan() async throws -> [ActivePort] {
        let output = try await runner()
        let parsed = PortParser.parse(output)
        return await enricher.enrich(ports: parsed)
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
