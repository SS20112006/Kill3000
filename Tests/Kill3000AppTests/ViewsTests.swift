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

    func testEmptyStateViewVariations() {
        let defaultEmptyState = EmptyStateView(isFiltered: false)
        XCTAssertFalse(defaultEmptyState.isFiltered)
        XCTAssertNotNil(defaultEmptyState.body)

        let filteredEmptyState = EmptyStateView(isFiltered: true)
        XCTAssertTrue(filteredEmptyState.isFiltered)
        XCTAssertNotNil(filteredEmptyState.body)
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
}
