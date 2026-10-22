import XCTest
import Foundation
@testable import Kill3000Engine
@testable import Kill3000App

final class MockPortScanner: PortScanning, @unchecked Sendable {
    var stubbedPorts: [ActivePort]
    var stubbedError: (any Error)?
    var scanCallCount = 0

    init(stubbedPorts: [ActivePort] = [], stubbedError: (any Error)? = nil) {
        self.stubbedPorts = stubbedPorts
        self.stubbedError = stubbedError
    }

    func scan() async throws -> [ActivePort] {
        scanCallCount += 1
        if let stubbedError {
            throw stubbedError
        }
        return stubbedPorts
    }
}

final class MockProcessTerminator: ProcessTerminating, @unchecked Sendable {
    var terminatedPids: [pid_t] = []
    var stubbedError: (any Error)?

    init(stubbedError: (any Error)? = nil) {
        self.stubbedError = stubbedError
    }

    func terminate(port: ActivePort) async throws {
        try await terminate(pid: port.pid)
    }

    func terminate(pid: pid_t) async throws {
        if let stubbedError {
            throw stubbedError
        }
        terminatedPids.append(pid)
    }
}

final class URLRecorder: @unchecked Sendable {
    var openedURLs: [URL] = []

    func open(_ url: URL) -> Bool {
        openedURLs.append(url)
        return true
    }
}

final class PortListViewModelTests: XCTestCase {
    private let devPort1 = ActivePort(
        port: 3000,
        pid: 101,
        processName: "node",
        commandPath: "/usr/local/bin/node",
        user: "developer",
        protocols: ["IPv4", "IPv6"],
        category: .development
    )

    private let devPort2 = ActivePort(
        port: 5173,
        pid: 102,
        processName: "vite",
        commandPath: "/usr/local/bin/vite",
        user: "developer",
        protocols: ["IPv4"],
        category: .development
    )

    private let sysPort1 = ActivePort(
        port: 5353,
        pid: 80,
        processName: "mDNSResponder",
        commandPath: "/usr/sbin/mDNSResponder",
        user: "_mdnsresponder",
        protocols: ["IPv4", "IPv6"],
        category: .systemDaemon
    )

    private let sysPort2 = ActivePort(
        port: 49152,
        pid: 85,
        processName: "rapportd",
        commandPath: "/usr/libexec/rapportd",
        user: "_rapport",
        protocols: ["IPv4"],
        category: .systemDaemon
    )

    // MARK: - Initial State
    @MainActor
    func testInitialState() {
        let viewModel = PortListViewModel(
            scanner: MockPortScanner(),
            terminator: MockProcessTerminator()
        )

        XCTAssertTrue(viewModel.ports.isEmpty)
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertFalse(viewModel.showAllPorts)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.filteredPorts.isEmpty)
    }

    // MARK: - Filtering: showAllPorts
    @MainActor
    func testFilteringCategoryDefaultShowsOnlyDevelopment() {
        let scanner = MockPortScanner(stubbedPorts: [devPort1, devPort2, sysPort1, sysPort2])
        let viewModel = PortListViewModel(scanner: scanner, terminator: MockProcessTerminator())
        viewModel.ports = [devPort1, devPort2, sysPort1, sysPort2]

        // By default showAllPorts is false
        XCTAssertFalse(viewModel.showAllPorts)
        let filtered = viewModel.filteredPorts
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered.map(\.port), [3000, 5173])
        XCTAssertTrue(filtered.allSatisfy { $0.category == .development })
    }

    @MainActor
    func testFilteringCategoryWhenShowAllPortsIsTrue() {
        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: MockProcessTerminator())
        viewModel.ports = [devPort1, devPort2, sysPort1, sysPort2]
        viewModel.showAllPorts = true

        let filtered = viewModel.filteredPorts
        XCTAssertEqual(filtered.count, 4)
        XCTAssertEqual(filtered.map(\.port), [3000, 5173, 5353, 49152])
    }

    // MARK: - Filtering: Search Text
    @MainActor
    func testFilteringByPortNumber() {
        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: MockProcessTerminator())
        viewModel.ports = [devPort1, devPort2, sysPort1, sysPort2]

        viewModel.searchText = "3000"
        XCTAssertEqual(viewModel.filteredPorts.map(\.port), [3000])

        viewModel.searchText = "51"
        XCTAssertEqual(viewModel.filteredPorts.map(\.port), [5173])
    }

    @MainActor
    func testFilteringByProcessNameCaseInsensitive() {
        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: MockProcessTerminator())
        viewModel.ports = [devPort1, devPort2, sysPort1, sysPort2]

        viewModel.searchText = "NODE"
        XCTAssertEqual(viewModel.filteredPorts.map(\.port), [3000])

        viewModel.searchText = "   ViTe   "
        XCTAssertEqual(viewModel.filteredPorts.map(\.port), [5173])
    }

    @MainActor
    func testFilteringWithSearchTextAndShowAllPortsCombination() {
        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: MockProcessTerminator())
        viewModel.ports = [devPort1, devPort2, sysPort1, sysPort2]

        // Search for system daemon while showAllPorts is false -> should not find it
        viewModel.searchText = "mDNSResponder"
        viewModel.showAllPorts = false
        XCTAssertTrue(viewModel.filteredPorts.isEmpty)

        // Turn showAllPorts on -> should now find it
        viewModel.showAllPorts = true
        XCTAssertEqual(viewModel.filteredPorts.map(\.port), [5353])
    }

    @MainActor
    func testFilteringNoMatchReturnsEmpty() {
        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: MockProcessTerminator())
        viewModel.ports = [devPort1, devPort2]
        viewModel.searchText = "postgres"

        XCTAssertTrue(viewModel.filteredPorts.isEmpty)
    }

    // MARK: - Refresh (Single Scan)
    @MainActor
    func testRefreshSuccessPopulatesPortsAndClearsError() async {
        let scanner = MockPortScanner(stubbedPorts: [devPort1, devPort2])
        let viewModel = PortListViewModel(scanner: scanner, terminator: MockProcessTerminator())
        viewModel.errorMessage = "Previous error"

        await viewModel.refresh()

        XCTAssertEqual(viewModel.ports.count, 2)
        XCTAssertEqual(viewModel.ports.map(\.port), [3000, 5173])
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(scanner.scanCallCount, 1)
    }

    @MainActor
    func testRefreshFailureSetsErrorMessage() async {
        enum TestError: LocalizedError {
            case scanFailed
            var errorDescription: String? { "Lsof scan execution failed." }
        }
        let scanner = MockPortScanner(stubbedError: TestError.scanFailed)
        let viewModel = PortListViewModel(scanner: scanner, terminator: MockProcessTerminator())

        await viewModel.refresh()

        XCTAssertTrue(viewModel.ports.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.errorMessage, "Lsof scan execution failed.")
    }

    // MARK: - Polling Lifecycle
    @MainActor
    func testPollingLifecycleStartAndStop() async {
        let scanner = MockPortScanner(stubbedPorts: [devPort1])
        let viewModel = PortListViewModel(
            scanner: scanner,
            terminator: MockProcessTerminator(),
            pollingInterval: .milliseconds(50)
        )

        XCTAssertFalse(viewModel.isPolling)
        viewModel.startPolling()
        XCTAssertTrue(viewModel.isPolling)

        // Duplicate start call should be idempotent
        viewModel.startPolling()
        XCTAssertTrue(viewModel.isPolling)

        // Wait a short duration to let background scan run
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertGreaterThanOrEqual(scanner.scanCallCount, 1)

        viewModel.stopPolling()
        XCTAssertFalse(viewModel.isPolling)

        let countAtStop = scanner.scanCallCount
        try? await Task.sleep(for: .milliseconds(100))
        // Verify no further scans occurred after cancellation
        XCTAssertEqual(scanner.scanCallCount, countAtStop)
    }

    // MARK: - Process Termination
    @MainActor
    func testKillSuccessOptimisticallyRemovesPort() async {
        let terminator = MockProcessTerminator()
        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: terminator)
        viewModel.ports = [devPort1, devPort2]

        await viewModel.kill(port: devPort1)

        XCTAssertEqual(terminator.terminatedPids, [101])
        XCTAssertEqual(viewModel.ports.map(\.port), [5173])
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testKillFailureRestoresPortAndSetsErrorMessage() async {
        let terminator = MockProcessTerminator(stubbedError: TerminatorError.permissionDenied(101))
        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: terminator)
        viewModel.ports = [devPort1, devPort2]

        await viewModel.kill(port: devPort1)

        // Process was not terminated
        XCTAssertEqual(terminator.terminatedPids, [])
        // Port was restored to the list
        XCTAssertEqual(viewModel.ports.map(\.port), [3000, 5173])
        // Friendly error message was set
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("Insufficient permissions") == true)
        // Error message must not leak file paths
        XCTAssertFalse(viewModel.errorMessage?.contains("at /") == true)
    }

    @MainActor
    func testKillProtectedProcessRefused() async {
        let terminator = MockProcessTerminator(stubbedError: TerminatorError.protectedProcess(1))
        let protectedPort = ActivePort(
            port: 80,
            pid: 1,
            processName: "launchd",
            commandPath: "/sbin/launchd",
            user: "root",
            protocols: ["IPv4"],
            category: .systemDaemon
        )
        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: terminator)
        viewModel.ports = [protectedPort, devPort1]

        await viewModel.kill(port: protectedPort)

        XCTAssertEqual(viewModel.ports.count, 2)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("protected") == true)
    }

    @MainActor
    func testKillPortNumberSuccess() async {
        let terminator = MockProcessTerminator()
        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: terminator)
        viewModel.ports = [devPort1, devPort2]

        let result = await viewModel.killPortNumber(3000)

        XCTAssertTrue(result)
        XCTAssertEqual(terminator.terminatedPids, [101])
        XCTAssertEqual(viewModel.ports.map(\.port), [5173])
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testKillPortNumberInvalidRange() async {
        let terminator = MockProcessTerminator()
        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: terminator)

        let resultZero = await viewModel.killPortNumber(0)
        XCTAssertFalse(resultZero)
        XCTAssertNotNil(viewModel.errorMessage)

        let resultTooHigh = await viewModel.killPortNumber(70000)
        XCTAssertFalse(resultTooHigh)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(terminator.terminatedPids.isEmpty)
    }

    @MainActor
    func testKillPortNumberNotFound() async {
        let scanner = MockPortScanner(stubbedPorts: [])
        let terminator = MockProcessTerminator()
        let viewModel = PortListViewModel(scanner: scanner, terminator: terminator)
        viewModel.ports = [devPort1]

        let result = await viewModel.killPortNumber(8080)

        XCTAssertFalse(result)
        XCTAssertEqual(viewModel.errorMessage, "Nenhum processo ativo encontrado na porta 8080.")
        XCTAssertTrue(terminator.terminatedPids.isEmpty)
    }

    @MainActor
    func testKillPortNumberTriggersScanWhenNotInMemory() async {
        let scanner = MockPortScanner(stubbedPorts: [devPort1])
        let terminator = MockProcessTerminator()
        let viewModel = PortListViewModel(scanner: scanner, terminator: terminator)
        // Memory currently empty
        XCTAssertTrue(viewModel.ports.isEmpty)

        let result = await viewModel.killPortNumber(3000)

        XCTAssertTrue(result)
        XCTAssertEqual(scanner.scanCallCount, 1)
        XCTAssertEqual(terminator.terminatedPids, [101])
        XCTAssertTrue(viewModel.ports.isEmpty)
    }

    @MainActor
    func testKillBatchSuccess() async {
        let terminator = MockProcessTerminator()
        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: terminator)
        viewModel.ports = [devPort1, devPort2, sysPort1]

        let count = await viewModel.killBatch(ports: [devPort1, devPort2])

        XCTAssertEqual(count, 2)
        XCTAssertEqual(terminator.terminatedPids, [101, 102])
        XCTAssertEqual(viewModel.ports.map(\.port), [5353])
    }

    @MainActor
    func testKillAllCategory() async {
        let orphanDev = ActivePort(
            port: 4000,
            pid: 105,
            processName: "node",
            user: "dev",
            protocols: ["IPv4"],
            category: .development,
            isOrphan: true,
            recommendation: .recommended(reason: "Orphan")
        )
        let terminator = MockProcessTerminator()
        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: terminator)
        viewModel.ports = [devPort1, devPort2, orphanDev, sysPort1]

        // Kill only suggested
        let suggestedCount = await viewModel.killAll(category: .suggested)
        XCTAssertEqual(suggestedCount, 1)
        XCTAssertEqual(terminator.terminatedPids, [105])
        XCTAssertEqual(viewModel.ports.map(\.port), [3000, 5173, 5353])

        // Kill all dev
        let devCount = await viewModel.killAll(category: .dev)
        XCTAssertEqual(devCount, 2)
        XCTAssertEqual(terminator.terminatedPids, [105, 101, 102])
        XCTAssertEqual(viewModel.ports.map(\.port), [5353])
    }

    // MARK: - Open in Browser
    @MainActor
    func testOpenInBrowserSuccess() {
        let recorder = URLRecorder()
        let viewModel = PortListViewModel(
            scanner: MockPortScanner(),
            terminator: MockProcessTerminator(),
            urlOpener: { recorder.open($0) }
        )

        let success = viewModel.openInBrowser(port: 3000)

        XCTAssertTrue(success)
        XCTAssertEqual(recorder.openedURLs.count, 1)
        XCTAssertEqual(recorder.openedURLs.first?.absoluteString, "http://localhost:3000")
    }

    @MainActor
    func testOpenInBrowserInvalidPort() {
        let recorder = URLRecorder()
        let viewModel = PortListViewModel(
            scanner: MockPortScanner(),
            terminator: MockProcessTerminator(),
            urlOpener: { recorder.open($0) }
        )

        let successNegative = viewModel.openInBrowser(port: -1)
        let successZero = viewModel.openInBrowser(port: 0)
        let successTooHigh = viewModel.openInBrowser(port: 70000)

        XCTAssertFalse(successNegative)
        XCTAssertFalse(successZero)
        XCTAssertFalse(successTooHigh)
        XCTAssertTrue(recorder.openedURLs.isEmpty)
    }

    // MARK: - Enhanced Search & Project Operations
    @MainActor
    func testFilteringByProjectName() {
        let enrichedPort = ActivePort(
            port: 3000,
            pid: 101,
            processName: "node",
            user: "developer",
            protocols: ["IPv4"],
            category: .development,
            projectOrAppName: "my-store-frontend"
        )
        let otherPort = ActivePort(
            port: 5173,
            pid: 102,
            processName: "vite",
            user: "developer",
            protocols: ["IPv4"],
            category: .development,
            projectOrAppName: "admin-dashboard"
        )

        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: MockProcessTerminator())
        viewModel.ports = [enrichedPort, otherPort]

        viewModel.searchText = "store"
        XCTAssertEqual(viewModel.filteredPorts.map(\.port), [3000])

        viewModel.searchText = "dashboard"
        XCTAssertEqual(viewModel.filteredPorts.map(\.port), [5173])
    }

    @MainActor
    func testFilteringByFramework() {
        let nextPort = ActivePort(
            port: 3000,
            pid: 101,
            processName: "node",
            user: "developer",
            protocols: ["IPv4"],
            category: .development,
            framework: "Next.js"
        )
        let djangoPort = ActivePort(
            port: 8000,
            pid: 102,
            processName: "python3",
            user: "developer",
            protocols: ["IPv4"],
            category: .development,
            framework: "Django"
        )

        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: MockProcessTerminator())
        viewModel.ports = [nextPort, djangoPort]

        viewModel.searchText = "next"
        XCTAssertEqual(viewModel.filteredPorts.map(\.port), [3000])

        viewModel.searchText = "django"
        XCTAssertEqual(viewModel.filteredPorts.map(\.port), [8000])
    }

    @MainActor
    func testFilteringByWorkingDirectory() {
        let shopPort = ActivePort(
            port: 3000,
            pid: 101,
            processName: "node",
            user: "developer",
            protocols: ["IPv4"],
            category: .development,
            workingDirectory: "/Users/dev/repos/shop"
        )

        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: MockProcessTerminator())
        viewModel.ports = [shopPort]

        viewModel.searchText = "repos/shop"
        XCTAssertEqual(viewModel.filteredPorts.map(\.port), [3000])
    }

    @MainActor
    func testOpenProjectFolderSuccessAndFailure() {
        let recorder = URLRecorder()
        let viewModel = PortListViewModel(
            scanner: MockPortScanner(),
            terminator: MockProcessTerminator(),
            folderOpener: { recorder.open($0) }
        )

        // Valid path
        let success = viewModel.openProjectFolder(path: "/Users/dev/my-project")
        XCTAssertTrue(success)
        XCTAssertEqual(recorder.openedURLs.first?.path, "/Users/dev/my-project")

        // Invalid empty path
        let failEmpty = viewModel.openProjectFolder(path: "")
        XCTAssertFalse(failEmpty)

        // Invalid root path
        let failRoot = viewModel.openProjectFolder(path: "/")
        XCTAssertFalse(failRoot)
    }

    @MainActor
    func testFilterCategorySuggestedAndCounters() {
        let activeDevPort = ActivePort(
            port: 3000,
            pid: 101,
            processName: "node",
            user: "dev",
            protocols: ["IPv4"],
            category: .development,
            recommendation: .active(reason: "Active dev")
        )
        let orphanDevPort = ActivePort(
            port: 5173,
            pid: 102,
            processName: "vite",
            user: "dev",
            protocols: ["IPv4"],
            category: .development,
            isOrphan: true,
            recommendation: .recommended(reason: "Processo órfão")
        )
        let systemPort = ActivePort(
            port: 5000,
            pid: 103,
            processName: "ControlCenter",
            user: "root",
            protocols: ["IPv4"],
            category: .systemDaemon,
            recommendation: .systemProtected(reason: "System")
        )

        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: MockProcessTerminator())
        viewModel.ports = [activeDevPort, orphanDevPort, systemPort]

        // Counters
        XCTAssertEqual(viewModel.totalPortsCount, 3)
        XCTAssertEqual(viewModel.devPortsCount, 2)
        XCTAssertEqual(viewModel.suggestedPortsCount, 1)

        // Default .dev category: only dev ports
        viewModel.filterCategory = .dev
        XCTAssertEqual(viewModel.filteredPorts.map(\.port), [3000, 5173])
        XCTAssertFalse(viewModel.showAllPorts)

        // .suggested category: only orphan/recommended to kill
        viewModel.filterCategory = .suggested
        XCTAssertEqual(viewModel.filteredPorts.map(\.port), [5173])
        XCTAssertFalse(viewModel.showAllPorts)

        // .all category: all ports
        viewModel.filterCategory = .all
        XCTAssertEqual(viewModel.filteredPorts.map(\.port), [3000, 5173, 5000])
        XCTAssertTrue(viewModel.showAllPorts)

        // Mutating showAllPorts updates filterCategory
        viewModel.showAllPorts = false
        XCTAssertEqual(viewModel.filterCategory, .dev)

        viewModel.showAllPorts = true
        XCTAssertEqual(viewModel.filterCategory, .all)
    }

    @MainActor
    func testFilterCategoryMyPortsAndCounters() {
        let userCreatedDevPort = ActivePort(
            port: 3000,
            pid: 101,
            processName: "node",
            commandPath: "/usr/local/bin/node",
            user: "developer",
            protocols: ["IPv4"],
            category: .development,
            isUserCreated: true
        )
        let backgroundAppPort = ActivePort(
            port: 83285,
            pid: 888,
            processName: "Spotify",
            commandPath: "/Applications/Spotify.app/Contents/MacOS/Spotify",
            user: "developer",
            protocols: ["IPv4"],
            category: .development,
            isUserCreated: false
        )
        let systemPort = ActivePort(
            port: 5000,
            pid: 103,
            processName: "ControlCenter",
            commandPath: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter",
            user: "root",
            protocols: ["IPv4"],
            category: .systemDaemon,
            isUserCreated: false
        )

        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: MockProcessTerminator())
        viewModel.ports = [userCreatedDevPort, backgroundAppPort, systemPort]

        XCTAssertEqual(viewModel.totalPortsCount, 3)
        XCTAssertEqual(viewModel.devPortsCount, 2)
        XCTAssertEqual(viewModel.myPortsCount, 1)

        // Filter by .myPorts
        viewModel.filterCategory = .myPorts
        XCTAssertEqual(viewModel.filteredPorts.map(\.port), [3000])

        // Filter by .dev
        viewModel.filterCategory = .dev
        XCTAssertEqual(viewModel.filteredPorts.map(\.port), [3000, 83285])
    }

    @MainActor
    func testKillAllMyPortsCategory() async {
        let userPort1 = ActivePort(
            port: 3000,
            pid: 101,
            processName: "node",
            user: "developer",
            protocols: ["IPv4"],
            category: .development,
            isUserCreated: true
        )
        let userPort2 = ActivePort(
            port: 5173,
            pid: 102,
            processName: "vite",
            user: "developer",
            protocols: ["IPv4"],
            category: .development,
            isUserCreated: true
        )
        let backgroundAppPort = ActivePort(
            port: 7768,
            pid: 103,
            processName: "Spotify",
            user: "developer",
            protocols: ["IPv4"],
            category: .development,
            isUserCreated: false
        )

        let terminator = MockProcessTerminator()
        let viewModel = PortListViewModel(scanner: MockPortScanner(), terminator: terminator)
        viewModel.ports = [userPort1, userPort2, backgroundAppPort]

        let count = await viewModel.killAll(category: .myPorts)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(terminator.terminatedPids, [101, 102])
        XCTAssertEqual(viewModel.ports.map(\.port), [7768])
    }
}
