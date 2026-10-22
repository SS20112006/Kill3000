import XCTest
@testable import Kill3000Engine

final class PortScannerTests: XCTestCase {

    func testPortScannerWithInjectedOutput() async throws {
        let sampleOutput = """
        COMMAND     PID       USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        node       5678 developer   22u  IPv4 0x1234567890abcdef      0t0  TCP 127.0.0.1:3000 (LISTEN)
        node       5678 developer   23u  IPv6 0xabcdef1234567890      0t0  TCP [::1]:3000 (LISTEN)
        vite       9876 developer   15u  IPv4 0xfeedfacecafebeef      0t0  TCP *:5173 (LISTEN)
        """

        let scanner = PortScanner(runner: {
            sampleOutput
        })

        let ports = try await scanner.scan()

        XCTAssertEqual(ports.count, 2)

        XCTAssertEqual(ports[0].port, 3000)
        XCTAssertEqual(ports[0].pid, 5678)
        XCTAssertEqual(ports[0].processName, "node")
        XCTAssertEqual(ports[0].protocols, ["IPv4", "IPv6"])
        XCTAssertEqual(ports[0].category, ProcessCategory.development)

        XCTAssertEqual(ports[1].port, 5173)
        XCTAssertEqual(ports[1].pid, 9876)
        XCTAssertEqual(ports[1].processName, "vite")
        XCTAssertEqual(ports[1].category, ProcessCategory.development)
    }

    func testPortScannerEmptyOutput() async throws {
        let scanner = PortScanner(runner: {
            ""
        })

        let ports = try await scanner.scan()
        XCTAssertTrue(ports.isEmpty)
    }

    func testPortScannerRealSystemExecution() async throws {
        // Runs against the local /usr/sbin/lsof
        let scanner = PortScanner()
        let ports = try await scanner.scan()

        // Real system might have 0 or more listening ports, but shouldn't throw
        for port in ports {
            XCTAssertGreaterThanOrEqual(port.port, 1)
            XCTAssertLessThanOrEqual(port.port, 65535)
            XCTAssertGreaterThan(port.pid, 1)
            XCTAssertFalse(port.processName.isEmpty)
        }
    }
}
