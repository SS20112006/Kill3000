import Foundation
import AppKit
import Observation
import Kill3000Engine

/// Observable view model managing active port state, live background polling,
/// search/category filtering, and process operations for Kill3000.
@Observable
@MainActor
public final class PortListViewModel {
    public typealias URLOpener = @Sendable (URL) -> Bool

    /// Full list of active listening ports discovered on the system.
    public var ports: [ActivePort] = []

    /// Current filter text query matching port number or process name.
    public var searchText: String = ""

    /// When `false`, displays only `.development` servers.
    /// When `true`, displays all listening ports including system daemons.
    public var showAllPorts: Bool = false

    /// Indicates whether a scan is currently executing.
    public var isLoading: Bool = false

    /// User-friendly error message if an operation (scan or kill) fails.
    public var errorMessage: String? = nil

    /// Indicates whether continuous background polling is currently active.
    public var isPolling: Bool {
        session.task != nil && !(session.task?.isCancelled ?? true)
    }

    /// Computed collection of ports filtered by category and search query.
    public var filteredPorts: [ActivePort] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return ports.filter { port in
            // Category filter: hide system daemons unless showAllPorts is enabled
            if !showAllPorts && port.category != .development {
                return false
            }

            // Search query filter: empty query matches all
            guard !trimmedQuery.isEmpty else {
                return true
            }

            let matchesPort = String(port.port).localizedCaseInsensitiveContains(trimmedQuery)
            let matchesProcess = port.processName.localizedCaseInsensitiveContains(trimmedQuery)

            return matchesPort || matchesProcess
        }
    }

    private let scanner: any PortScanning
    private let terminator: any ProcessTerminating
    private let urlOpener: URLOpener
    private let pollingInterval: Duration

    private final class PollingSession: @unchecked Sendable {
        var task: Task<Void, Never>?
        func cancel() {
            task?.cancel()
            task = nil
        }
    }

    @ObservationIgnored
    private let session = PollingSession()

    /// Initializes the view model with injectable dependencies for robust testability.
    ///
    /// - Parameters:
    ///   - scanner: Port scanning engine (defaults to `PortScanner()`).
    ///   - terminator: Process termination engine (defaults to `ProcessTerminator()`).
    ///   - pollingInterval: Interval between automatic scans (defaults to 2 seconds).
    ///   - urlOpener: Closure for opening web URLs (defaults to `NSWorkspace.shared.open`).
    public init(
        scanner: any PortScanning = PortScanner(),
        terminator: any ProcessTerminating = ProcessTerminator(),
        pollingInterval: Duration = .seconds(2),
        urlOpener: @escaping URLOpener = { NSWorkspace.shared.open($0) }
    ) {
        self.scanner = scanner
        self.terminator = terminator
        self.pollingInterval = pollingInterval
        self.urlOpener = urlOpener
    }

    /// Performs a single asynchronous scan of active ports.
    public func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let scannedPorts = try await scanner.scan()
            self.ports = scannedPorts
            self.errorMessage = nil
        } catch {
            self.errorMessage = sanitizeErrorMessage(error.localizedDescription)
        }
    }

    /// Starts periodic background polling of active listening ports.
    ///
    /// Safe to call multiple times (idempotent).
    public func startPolling() {
        guard session.task == nil else { return }

        session.task = Task { [weak self] in
            guard let self else { return }
            await self.refresh()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: self.pollingInterval)
                } catch {
                    break
                }

                guard !Task.isCancelled else { break }
                await self.refresh()
            }
        }
    }

    /// Halts background polling and frees background tasks.
    public func stopPolling() {
        session.cancel()
    }

    /// Asynchronously terminates the process associated with an active port.
    ///
    /// Implements optimistic UI removal: the port is removed immediately,
    /// and restored to the list if termination fails.
    ///
    /// - Parameter port: The active port to terminate.
    public func kill(port: ActivePort) async {
        guard let index = ports.firstIndex(where: { $0.id == port.id }) else {
            return
        }

        let removedPort = ports.remove(at: index)

        do {
            try await terminator.terminate(port: removedPort)
            self.errorMessage = nil
        } catch {
            // Restore port at its sorted position on failure
            if !ports.contains(where: { $0.id == removedPort.id }) {
                ports.append(removedPort)
                ports.sort { $0.port < $1.port }
            }
            self.errorMessage = sanitizeErrorMessage(error.localizedDescription)
        }
    }

    /// Opens the localhost URL for the specified port in the user's default browser.
    ///
    /// - Parameter port: The port number (must be in range 1...65535).
    /// - Returns: `true` if successfully launched; `false` if invalid or failed.
    @discardableResult
    public func openInBrowser(port: Int) -> Bool {
        guard port > 0 && port <= 65535,
              let url = URL(string: "http://localhost:\(port)") else {
            return false
        }
        return urlOpener(url)
    }

    /// Sanitizes client-facing error strings, guaranteeing no internal filesystem paths or stack traces leak.
    private func sanitizeErrorMessage(_ message: String) -> String {
        if message.contains("at /") || message.contains("/Users/") || message.contains("/System/") {
            return "An unexpected system error occurred during execution."
        }
        return message
    }

    deinit {
        session.cancel()
    }
}
