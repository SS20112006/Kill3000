import XCTest
@testable import Kill3000Engine

final class ProcessClassifierTests: XCTestCase {
    func testDevelopmentToolsClassification() {
        let devTools = [
            "node",
            "vite",
            "bun",
            "python3",
            "go",
            "docker-proxy",
            "cargo",
            "ruby",
            "postgres",
            "redis-server",
            "deno",
            "java"
        ]

        for tool in devTools {
            XCTAssertEqual(
                ProcessInspector.classify(processName: tool),
                .development,
                "Expected \(tool) to be classified as .development"
            )
        }
    }

    func testSystemDaemonsClassification() {
        let daemons = [
            "mDNSResponder",
            "rapportd",
            "cupsd",
            "launchd",
            "ControlCenter",
            "identityservicesd",
            "sharingd"
        ]

        for daemon in daemons {
            XCTAssertEqual(
                ProcessInspector.classify(processName: daemon),
                .systemDaemon,
                "Expected \(daemon) to be classified as .systemDaemon"
            )
        }
    }

    func testCaseInsensitiveAndWhitespaceResilience() {
        XCTAssertEqual(ProcessInspector.classify(processName: "  node  "), .development)
        XCTAssertEqual(ProcessInspector.classify(processName: "VITE"), .development)
        XCTAssertEqual(ProcessInspector.classify(processName: "MDNSRESPONDER"), .systemDaemon)
        XCTAssertEqual(ProcessInspector.classify(processName: "  rapportd\n"), .systemDaemon)
    }

    func testTruncatedProcessNamesFromLsof() {
        XCTAssertEqual(ProcessInspector.classify(processName: "ControlCe"), .systemDaemon)
        XCTAssertEqual(ProcessInspector.classify(processName: "redis-ser"), .development)
        XCTAssertEqual(ProcessInspector.classify(processName: "docker-pr"), .development)
        XCTAssertEqual(ProcessInspector.classify(processName: "mDNSRespo"), .systemDaemon)
        XCTAssertEqual(ProcessInspector.classify(processName: "identitys"), .systemDaemon)
    }

    func testUnknownProcessDefaultsToDevelopment() {
        XCTAssertEqual(ProcessInspector.classify(processName: "my-custom-api"), .development)
        XCTAssertEqual(ProcessInspector.classify(processName: "custom_backend"), .development)
    }
}
