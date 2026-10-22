import XCTest
import SwiftUI
@testable import Kill3000Engine
@testable import Kill3000App

@MainActor
final class ViewsTests: XCTestCase {
    func testFilterBarViewInstantiationAndBindings() {
        var searchText = "3000"
        var showAllPorts = true

        let searchBinding = Binding<String>(
            get: { searchText },
            set: { searchText = $0 }
        )
        let showAllBinding = Binding<Bool>(
            get: { showAllPorts },
            set: { showAllPorts = $0 }
        )

        let filterBar = FilterBarView(searchText: searchBinding, showAllPorts: showAllBinding)
        XCTAssertNotNil(filterBar.body)
        XCTAssertEqual(filterBar.searchText, "3000")
        XCTAssertTrue(filterBar.showAllPorts)
        XCTAssertEqual(filterBar.devCount, 0)
        XCTAssertEqual(filterBar.totalCount, 0)
    }

    func testFilterBarViewWithPortCounters() {
        var searchText = ""
        var showAllPorts = false

        let searchBinding = Binding<String>(
            get: { searchText },
            set: { searchText = $0 }
        )
        let showAllBinding = Binding<Bool>(
            get: { showAllPorts },
            set: { showAllPorts = $0 }
        )

        let filterBar = FilterBarView(
            searchText: searchBinding,
            showAllPorts: showAllBinding,
            devCount: 3,
            totalCount: 8
        )
        XCTAssertNotNil(filterBar.body)
        XCTAssertEqual(filterBar.devCount, 3)
        XCTAssertEqual(filterBar.totalCount, 8)
    }

    func testPortRowViewActions() {
        let testPort = ActivePort(
            port: 3000,
            pid: 12345,
            processName: "node",
            commandPath: "/usr/local/bin/node",
            user: "developer",
            protocols: ["IPv4", "IPv6"],
            category: .development
        )

        var openedPort: Int?
        var killedPort: ActivePort?

        let row = PortRowView(
            port: testPort,
            onOpenInBrowser: { openedPort = $0 },
            onKill: { killedPort = $0 }
        )

        XCTAssertNotNil(row.body)
        XCTAssertEqual(row.port.port, 3000)

        row.onOpenInBrowser(3000)
        XCTAssertEqual(openedPort, 3000)

        row.onKill(testPort)
        XCTAssertEqual(killedPort?.id, "3000-12345")
    }

    func testPortRowViewSystemDaemonCategory() {
        let systemPort = ActivePort(
            port: 52311,
            pid: 619,
            processName: "rapportd",
            commandPath: "/usr/libexec/rapportd",
            user: "developer",
            protocols: ["IPv4"],
            category: .systemDaemon
        )

        let row = PortRowView(
            port: systemPort,
            onOpenInBrowser: { _ in },
            onKill: { _ in }
        )

        XCTAssertNotNil(row.body)
        XCTAssertEqual(row.port.category, .systemDaemon)
        XCTAssertEqual(row.port.processName, "rapportd")
    }

    func testPortRowViewWithFolderAction() {
        let devPort = ActivePort(
            port: 3000,
            pid: 1234,
            processName: "node",
            user: "developer",
            protocols: ["IPv4"],
            category: .development,
            projectOrAppName: "my-shop",
            workingDirectory: "/Users/developer/Projects/my-shop",
            framework: "Next.js"
        )

        var openedFolder: String?
        let row = PortRowView(
            port: devPort,
            onOpenInBrowser: { _ in },
            onKill: { _ in },
            onOpenFolder: { openedFolder = $0 }
        )

        XCTAssertNotNil(row.body)
        XCTAssertEqual(row.port.workingDirectory, "/Users/developer/Projects/my-shop")
        row.onOpenFolder?("/Users/developer/Projects/my-shop")
        XCTAssertEqual(openedFolder, "/Users/developer/Projects/my-shop")
    }

    func testPortRowViewOrphanState() {
        let orphanPort = ActivePort(
            port: 5173,
            pid: 9876,
            processName: "vite",
            user: "developer",
            protocols: ["IPv4"],
            category: .development,
            isOrphan: true
        )

        let row = PortRowView(
            port: orphanPort,
            onOpenInBrowser: { _ in },
            onKill: { _ in }
        )

        XCTAssertNotNil(row.body)
        XCTAssertTrue(row.port.isOrphan)
        XCTAssertTrue(row.port.recommendation.isRecommendedToKill)
    }

    func testEmptyStateViewVariations() {
        let defaultEmptyState = EmptyStateView(isFiltered: false)
        XCTAssertFalse(defaultEmptyState.isFiltered)
        XCTAssertNotNil(defaultEmptyState.body)

        var cleared = false
        let filteredEmptyState = EmptyStateView(isFiltered: true, onClearFilter: { cleared = true })
        XCTAssertTrue(filteredEmptyState.isFiltered)
        XCTAssertNotNil(filteredEmptyState.body)

        filteredEmptyState.onClearFilter?()
        XCTAssertTrue(cleared)
    }

    func testPopoverContainerViewIntegration() {
        let mockScanner = MockPortScanner(stubbedPorts: [
            ActivePort(
                port: 5173,
                pid: 4567,
                processName: "vite",
                commandPath: nil,
                user: "developer",
                protocols: ["IPv4"],
                category: .development
            )
        ])
        let viewModel = PortListViewModel(scanner: mockScanner)

        let container = PopoverContainerView(viewModel: viewModel)
        XCTAssertNotNil(container.body)
        XCTAssertEqual(container.viewModel.ports.count, 0)
    }

    func testFilterBarViewWithCategoryBinding() {
        var category = PortFilterCategory.dev
        var searchText = ""

        let filterBar = FilterBarView(
            searchText: Binding(get: { searchText }, set: { searchText = $0 }),
            filterCategory: Binding(get: { category }, set: { category = $0 }),
            devCount: 3,
            suggestedCount: 2,
            totalCount: 7
        )

        XCTAssertNotNil(filterBar.body)
        XCTAssertEqual(filterBar.devCount, 3)
        XCTAssertEqual(filterBar.suggestedCount, 2)
        XCTAssertEqual(filterBar.totalCount, 7)
        XCTAssertFalse(filterBar.showAllPorts)

        category = .all
        XCTAssertTrue(filterBar.showAllPorts)
    }

    func testDashboardViewInstantiationAndMetricDisplay() {
        let testPorts = [
            ActivePort(
                port: 3000,
                pid: 101,
                processName: "node",
                user: "developer",
                protocols: ["IPv4"],
                category: .development,
                projectOrAppName: "my-frontend",
                workingDirectory: "/Users/developer/my-frontend",
                framework: "Next.js"
            ),
            ActivePort(
                port: 5173,
                pid: 102,
                processName: "vite",
                user: "developer",
                protocols: ["IPv4"],
                category: .development,
                isOrphan: true,
                recommendation: .recommended(reason: "Processo órfão")
            )
        ]

        let mockScanner = MockPortScanner(stubbedPorts: testPorts)
        let viewModel = PortListViewModel(scanner: mockScanner)
        viewModel.ports = testPorts

        let dashboard = DashboardView(viewModel: viewModel)
        XCTAssertNotNil(dashboard.body)
        XCTAssertEqual(viewModel.totalPortsCount, 2)
        XCTAssertEqual(viewModel.devPortsCount, 2)
        XCTAssertEqual(viewModel.suggestedPortsCount, 1)
    }

    func testDashboardViewBatchKillTypeIdentifiers() {
        let myPorts = DashboardView.BatchKillType.myPorts
        let dev = DashboardView.BatchKillType.dev
        let suggested = DashboardView.BatchKillType.suggested
        let displayed = DashboardView.BatchKillType.displayed

        XCTAssertEqual(myPorts.id, "myPorts")
        XCTAssertEqual(dev.id, "dev")
        XCTAssertEqual(suggested.id, "suggested")
        XCTAssertEqual(displayed.id, "displayed")
    }

    func testFilterBarViewWithMyPortsCategoryBinding() {
        var category = PortFilterCategory.myPorts
        var searchText = ""

        let filterBar = FilterBarView(
            searchText: Binding(get: { searchText }, set: { searchText = $0 }),
            filterCategory: Binding(get: { category }, set: { category = $0 }),
            myPortsCount: 2,
            devCount: 4,
            suggestedCount: 1,
            totalCount: 8
        )

        XCTAssertNotNil(filterBar.body)
        XCTAssertEqual(filterBar.myPortsCount, 2)
        XCTAssertEqual(filterBar.devCount, 4)
        XCTAssertEqual(filterBar.suggestedCount, 1)
        XCTAssertEqual(filterBar.totalCount, 8)
        XCTAssertFalse(filterBar.showAllPorts)
    }

    func testPortRowViewUserCreatedBadge() {
        let userPort = ActivePort(
            port: 3000,
            pid: 101,
            processName: "node",
            user: "dev",
            protocols: ["IPv4"],
            category: .development,
            isUserCreated: true
        )

        let row = PortRowView(
            port: userPort,
            onOpenInBrowser: { _ in },
            onKill: { _ in }
        )

        XCTAssertNotNil(row.body)
        XCTAssertTrue(row.port.isUserCreated)
    }

    func testDashboardViewWithErrorMessageRendersBanner() {
        let viewModel = PortListViewModel(scanner: MockPortScanner())
        viewModel.errorMessage = "Falha ao terminar processo: Permissão negada."

        let dashboard = DashboardView(viewModel: viewModel)
        XCTAssertNotNil(dashboard.body)
        XCTAssertEqual(viewModel.errorMessage, "Falha ao terminar processo: Permissão negada.")
    }
}
