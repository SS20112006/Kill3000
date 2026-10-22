import Foundation
import AppKit
import Observation
import Kill3000Engine

/// Filter categories for active listening ports.
public enum PortFilterCategory: String, Sendable, CaseIterable, Identifiable {
    case myPorts = "Minhas"
    case dev = "Dev"
    case suggested = "Sugeridas"
    case all = "Todas"

    public var id: String { rawValue }
}

/// Observable view model managing active port state, live background polling,
/// search/category filtering, and process operations for Kill3000.
@Observable
@MainActor
public final class PortListViewModel {
    public typealias URLOpener = @Sendable (URL) -> Bool
    public typealias FolderOpener = @Sendable (URL) -> Bool

    /// Full list of active listening ports discovered on the system.
    public var ports: [ActivePort] = []

    /// Current filter text query matching port number, process, project, or framework.
    public var searchText: String = ""

    /// Active filter category selection.
    public var filterCategory: PortFilterCategory = .dev

    /// Backward compatibility accessor for legacy code and unit tests.
    /// When `false`, displays only `.development` servers.
    /// When `true`, displays all listening ports including system daemons.
    public var showAllPorts: Bool {
        get { filterCategory == .all }
        set { filterCategory = newValue ? .all : .dev }
    }

    /// Indicates whether a scan is currently executing.
    public var isLoading: Bool = false

    /// User-friendly error message if an operation (scan or kill) fails.
    public var errorMessage: String? = nil

    /// Indicates whether continuous background polling is currently active.
    public var isPolling: Bool {
        session.task != nil && !(session.task?.isCancelled ?? true)
    }

    /// Count of ports created directly by the user (local projects and dev servers).
    public var myPortsCount: Int {
        ports.filter { $0.isUserCreated }.count
    }

    /// Count of development servers.
    public var devPortsCount: Int {
        ports.filter { $0.category == .development }.count
    }

    /// Count of ports recommended to be terminated (e.g. orphans or stale idle servers).
    public var suggestedPortsCount: Int {
        ports.filter { $0.recommendation.isRecommendedToKill }.count
    }

    /// Total count of active listening ports.
    public var totalPortsCount: Int {
        ports.count
    }

    /// Computed collection of ports filtered by category and search query.
    public var filteredPorts: [ActivePort] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return ports.filter { port in
            // Category filter: Minhas, Dev, Sugeridas, or Todas
            switch filterCategory {
            case .myPorts:
                if !port.isUserCreated {
                    return false
                }
            case .dev:
                if port.category != .development {
                    return false
                }
            case .suggested:
                if !port.recommendation.isRecommendedToKill {
                    return false
                }
            case .all:
                break
            }

            // Search query filter: empty query matches all
            guard !trimmedQuery.isEmpty else {
                return true
            }

            let matchesPort = String(port.port).localizedCaseInsensitiveContains(trimmedQuery)
            let matchesProcess = port.processName.localizedCaseInsensitiveContains(trimmedQuery)
            let matchesProject = port.projectOrAppName?.localizedCaseInsensitiveContains(trimmedQuery) ?? false
            let matchesFramework = port.framework?.localizedCaseInsensitiveContains(trimmedQuery) ?? false
            let matchesDir = port.workingDirectory?.localizedCaseInsensitiveContains(trimmedQuery) ?? false

            return matchesPort || matchesProcess || matchesProject || matchesFramework || matchesDir
        }
    }

    private let scanner: any PortScanning
    private let terminator: any ProcessTerminating
    private let urlOpener: URLOpener
    private let folderOpener: FolderOpener
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
    ///   - folderOpener: Closure for opening project directory in Finder.
    public init(
        scanner: any PortScanning = PortScanner(),
        terminator: any ProcessTerminating = ProcessTerminator(),
        pollingInterval: Duration = .seconds(2),
        urlOpener: @escaping URLOpener = { NSWorkspace.shared.open($0) },
        folderOpener: @escaping FolderOpener = { url in
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
            return true
        }
    ) {
        self.scanner = scanner
        self.terminator = terminator
        self.pollingInterval = pollingInterval
        self.urlOpener = urlOpener
        self.folderOpener = folderOpener
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

    /// Asynchronously terminates any process listening on the specified port number.
    ///
    /// - Parameter portNumber: The port number to terminate (1...65535).
    /// - Returns: `true` if a process was found and terminated; `false` otherwise.
    @discardableResult
    public func killPortNumber(_ portNumber: Int) async -> Bool {
        guard (1...65535).contains(portNumber) else {
            self.errorMessage = "Porta inválida (\(portNumber)). Deve ser entre 1 e 65535."
            return false
        }

        var matchingPorts = ports.filter { $0.port == portNumber }

        // If not found in memory, try a fresh scan first to discover recently opened ports
        if matchingPorts.isEmpty {
            do {
                let freshPorts = try await scanner.scan()
                self.ports = freshPorts
                matchingPorts = freshPorts.filter { $0.port == portNumber }
            } catch {
                self.errorMessage = sanitizeErrorMessage(error.localizedDescription)
                return false
            }
        }

        guard !matchingPorts.isEmpty else {
            self.errorMessage = "Nenhum processo ativo encontrado na porta \(portNumber)."
            return false
        }

        var allSucceeded = true
        for port in matchingPorts {
            guard let index = ports.firstIndex(where: { $0.id == port.id }) else { continue }
            let removed = ports.remove(at: index)
            do {
                try await terminator.terminate(port: removed)
            } catch {
                if !ports.contains(where: { $0.id == removed.id }) {
                    ports.append(removed)
                    ports.sort { $0.port < $1.port }
                }
                self.errorMessage = sanitizeErrorMessage(error.localizedDescription)
                allSucceeded = false
            }
        }

        if allSucceeded {
            self.errorMessage = nil
            return true
        }
        return false
    }

    /// Asynchronously terminates multiple active ports in sequence.
    ///
    /// - Parameter toKill: Collection of active ports to terminate.
    /// - Returns: The number of processes successfully terminated.
    @discardableResult
    public func killBatch(ports toKill: [ActivePort]) async -> Int {
        var successCount = 0
        for port in toKill {
            guard let index = ports.firstIndex(where: { $0.id == port.id }) else { continue }
            let removed = ports.remove(at: index)
            do {
                try await terminator.terminate(port: removed)
                successCount += 1
            } catch {
                if !ports.contains(where: { $0.id == removed.id }) {
                    ports.append(removed)
                    ports.sort { $0.port < $1.port }
                }
                self.errorMessage = sanitizeErrorMessage(error.localizedDescription)
            }
        }
        return successCount
    }

    /// Asynchronously terminates all ports matching the given category.
    ///
    /// - Parameter category: The filter category (.myPorts, .dev, .suggested, or .all).
    /// - Returns: The number of processes successfully terminated.
    @discardableResult
    public func killAll(category: PortFilterCategory) async -> Int {
        let targets: [ActivePort]
        switch category {
        case .myPorts:
            targets = ports.filter { $0.isUserCreated }
        case .dev:
            targets = ports.filter { $0.category == .development }
        case .suggested:
            targets = ports.filter { $0.recommendation.isRecommendedToKill }
        case .all:
            targets = ports
        }
        return await killBatch(ports: targets)
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

    /// Opens the project working directory in Finder.
    ///
    /// - Parameter path: The file system path to open.
    /// - Returns: `true` if opened successfully; `false` otherwise.
    @discardableResult
    public func openProjectFolder(path: String) -> Bool {
        guard !path.isEmpty && path != "/" else {
            return false
        }
        let url = URL(fileURLWithPath: path)
        return folderOpener(url)
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
