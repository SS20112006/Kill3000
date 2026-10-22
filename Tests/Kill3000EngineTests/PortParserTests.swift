import XCTest
@testable import Kill3000Engine

final class PortParserTests: XCTestCase {
    func testParseIPv4Listen() {
        let output = "node 1234 developer 10u IPv4 0x1234567890abcdef 0t0 TCP 127.0.0.1:3000 (LISTEN)\n"
        let ports = PortParser.parse(output)

        XCTAssertEqual(ports.count, 1)
        guard let first = ports.first else {
            XCTFail("Expected one active port")
            return
        }

        XCTAssertEqual(first.port, 3000)
        XCTAssertEqual(first.pid, 1234)
        XCTAssertEqual(first.processName, "node")
        XCTAssertEqual(first.user, "developer")
        XCTAssertEqual(first.protocols, ["IPv4"])
        XCTAssertEqual(first.category, .development)
    }

    func testParseIPv6Listen() {
        let output = "python3 4321 developer 5u IPv6 0xabcdef1234567890 0t0 TCP [::1]:8000 (LISTEN)\n"
        let ports = PortParser.parse(output)

        XCTAssertEqual(ports.count, 1)
        guard let first = ports.first else {
            XCTFail("Expected one active port")
            return
        }

        XCTAssertEqual(first.port, 8000)
        XCTAssertEqual(first.pid, 4321)
        XCTAssertEqual(first.processName, "python3")
        XCTAssertEqual(first.user, "developer")
        XCTAssertEqual(first.protocols, ["IPv6"])
        XCTAssertEqual(first.category, .development)
    }

    func testParseWildcardListen() {
        let output = "vite 5678 developer 12u IPv4 0x1122334455667788 0t0 TCP *:5173 (LISTEN)\n"
        let ports = PortParser.parse(output)

        XCTAssertEqual(ports.count, 1)
        guard let first = ports.first else {
            XCTFail("Expected one active port")
            return
        }

        XCTAssertEqual(first.port, 5173)
        XCTAssertEqual(first.pid, 5678)
        XCTAssertEqual(first.processName, "vite")
        XCTAssertEqual(first.user, "developer")
        XCTAssertEqual(first.protocols, ["IPv4"])
        XCTAssertEqual(first.category, .development)
    }

    func testParseDualStackDeduplication() {
        let output = """
        node 74096 simaosousa 34u IPv4 0x1234567890abcdef 0t0 TCP 127.0.0.1:3000 (LISTEN)
        node 74096 simaosousa 35u IPv6 0x3c6affc08505a31b 0t0 TCP [::1]:3000 (LISTEN)
        """
        let ports = PortParser.parse(output)

        XCTAssertEqual(ports.count, 1)
        guard let first = ports.first else {
            XCTFail("Expected one active port")
            return
        }

        XCTAssertEqual(first.port, 3000)
        XCTAssertEqual(first.pid, 74096)
        XCTAssertEqual(first.processName, "node")
        XCTAssertEqual(first.user, "simaosousa")
        XCTAssertEqual(first.protocols, ["IPv4", "IPv6"])
        XCTAssertEqual(first.category, .development)
    }

    func testParseIgnoresHeaderAndNoise() {
        let output = """
        COMMAND     PID       USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        lsof: WARNING: can't stat() fuse file system /Volumes/Mock
        rapportd    619 simaosousa   10u  IPv4 0x4422f33056debefa      0t0  TCP *:50266 (LISTEN)
        some_proc   999 user          1u  IPv4 0x123                   0t0  TCP 127.0.0.1:1234->127.0.0.1:4567 (ESTABLISHED)
        malformed or noisy log line without listen
        
        """
        let ports = PortParser.parse(output)

        XCTAssertEqual(ports.count, 1)
        guard let first = ports.first else {
            XCTFail("Expected one active port")
            return
        }

        XCTAssertEqual(first.port, 50266)
        XCTAssertEqual(first.pid, 619)
        XCTAssertEqual(first.processName, "rapportd")
        XCTAssertEqual(first.category, .systemDaemon)
    }

    func testParseEmptyOrWhitespaceInput() {
        XCTAssertTrue(PortParser.parse("").isEmpty)
        XCTAssertTrue(PortParser.parse("   \n\n\t  \n").isEmpty)
    }

    func testParseMultiplePortsSortedAscending() {
        let output = """
        node 100 user 1u IPv4 0x1 0t0 TCP *:8080 (LISTEN)
        bun  200 user 2u IPv4 0x2 0t0 TCP 127.0.0.1:3000 (LISTEN)
        vite 300 user 3u IPv4 0x3 0t0 TCP *:5173 (LISTEN)
        """
        let ports = PortParser.parse(output)

        XCTAssertEqual(ports.count, 3)
        XCTAssertEqual(ports.map(\.port), [3000, 5173, 8080])
        XCTAssertEqual(ports.map(\.processName), ["bun", "vite", "node"])
    }

    func testParseRealWorldMacOSLsofOutput() {
        let output = """
        COMMAND     PID       USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        rapportd    619 simaosousa   10u  IPv4 0x4422f33056debefa      0t0  TCP *:50266 (LISTEN)
        rapportd    619 simaosousa   11u  IPv6  0xc9a8c2bfccc8abb      0t0  TCP *:50266 (LISTEN)
        ControlCe   633 simaosousa    9u  IPv4 0x434a36ef68215bb6      0t0  TCP *:7000 (LISTEN)
        ControlCe   633 simaosousa   10u  IPv6 0x1ca34cc47f9763f8      0t0  TCP *:7000 (LISTEN)
        ControlCe   633 simaosousa   11u  IPv4  0x8becd2869bbcaf9      0t0  TCP *:5000 (LISTEN)
        ControlCe   633 simaosousa   12u  IPv6 0x71399b970a27d506      0t0  TCP *:5000 (LISTEN)
        redis-ser  1062 simaosousa    6u  IPv4 0xeb1c35c8bbf8fe10      0t0  TCP 127.0.0.1:6379 (LISTEN)
        redis-ser  1062 simaosousa    7u  IPv6 0xe0da0d4f371a01a1      0t0  TCP [::1]:6379 (LISTEN)
        """
        let ports = PortParser.parse(output)

        // 4 distinct ports: 5000 (ControlCe), 6379 (redis-ser), 7000 (ControlCe), 50266 (rapportd)
        XCTAssertEqual(ports.count, 4)
        XCTAssertEqual(ports.map(\.port), [5000, 6379, 7000, 50266])

        let port5000 = ports.first { $0.port == 5000 }
        XCTAssertNotNil(port5000)
        XCTAssertEqual(port5000?.protocols, ["IPv4", "IPv6"])
        XCTAssertEqual(port5000?.category, .systemDaemon)

        let redisPort = ports.first { $0.port == 6379 }
        XCTAssertNotNil(redisPort)
        XCTAssertEqual(redisPort?.processName, "redis-ser")
        XCTAssertEqual(redisPort?.protocols, ["IPv4", "IPv6"])
        XCTAssertEqual(redisPort?.category, .development)
    }
}
