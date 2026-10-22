import XCTest
import SwiftUI
@testable import Kill3000Engine
@testable import Kill3000App

@MainActor
final class Kill3000AppTests: XCTestCase {
    func testAppInitialization() {
        let app = Kill3000App()
        XCTAssertNotNil(app.body)
    }

    func testAppInitializationWithCustomViewModel() {
        let mockViewModel = PortListViewModel()
        let app = Kill3000App(viewModel: mockViewModel)
        XCTAssertNotNil(app.body)
    }
}
