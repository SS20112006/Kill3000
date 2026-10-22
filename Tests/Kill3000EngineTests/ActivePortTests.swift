import XCTest
@testable import Kill3000Engine

final class ActivePortTests: XCTestCase {
    func testActivePortInitialization() {
        let port = ActivePort(
            port: 3000,
            pid: 12345,
            processName: "node",
            commandPath: "/usr/local/bin/node",
            user: "developer",
            protocols: ["IPv4", "IPv6"],
            category: .development
        )

        XCTAssertEqual(port.port, 3000)
        XCTAssertEqual(port.pid, 12345)
        XCTAssertEqual(port.processName, "node")
        XCTAssertEqual(port.commandPath, "/usr/local/bin/node")
        XCTAssertEqual(port.user, "developer")
        XCTAssertEqual(port.protocols, ["IPv4", "IPv6"])
        XCTAssertEqual(port.category, .development)
    }

    func testActivePortIdFormat() {
        let port = ActivePort(
            port: 8080,
            pid: 9999,
            processName: "python3",
            user: "staff",
            protocols: ["IPv4"],
            category: .development
        )

        XCTAssertEqual(port.id, "8080-9999")
    }

    func testActivePortEquatableAndHashable() {
        let port1 = ActivePort(
            port: 5173,
            pid: 4567,
            processName: "vite",
            commandPath: "/opt/homebrew/bin/vite",
            user: "developer",
            protocols: ["IPv4"],
            category: .development
        )

        let port2 = ActivePort(
            port: 5173,
            pid: 4567,
            processName: "vite",
            commandPath: "/opt/homebrew/bin/vite",
            user: "developer",
            protocols: ["IPv4"],
            category: .development
        )

        let differentPort = ActivePort(
            port: 5174,
            pid: 4567,
            processName: "vite",
            commandPath: "/opt/homebrew/bin/vite",
            user: "developer",
            protocols: ["IPv4"],
            category: .development
        )

        XCTAssertEqual(port1, port2)
        XCTAssertNotEqual(port1, differentPort)

        var portSet: Set<ActivePort> = []
        portSet.insert(port1)
        portSet.insert(port2)
        XCTAssertEqual(portSet.count, 1)

        portSet.insert(differentPort)
        XCTAssertEqual(portSet.count, 2)
    }

    func testProcessCategoryValues() {
        XCTAssertEqual(ProcessCategory.development.rawValue, "Dev Server")
        XCTAssertEqual(ProcessCategory.systemDaemon.rawValue, "macOS System")
        XCTAssertEqual(ProcessCategory.allCases.count, 2)
    }

    func testActivePortCodable() throws {
        let original = ActivePort(
            port: 3000,
            pid: 1234,
            processName: "bun",
            commandPath: "/usr/local/bin/bun",
            user: "testuser",
            protocols: ["IPv4", "IPv6"],
            category: .development
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ActivePort.self, from: data)

        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.id, "3000-1234")
    }
}
