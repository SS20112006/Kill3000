import XCTest
import Darwin
@testable import Kill3000Engine

final class ProcessDetailsInspectorTests: XCTestCase {

    func testFrameworkDetectionFromArgsAndProcessName() {
        let inspector = ProcessDetailsInspector()

        // Next.js
        let nextData = inspector.inspect(
            pid: 999991,
            port: 3000,
            processName: "node",
            category: .development
        )
        // With port 3000 fallback or args
        XCTAssertEqual(nextData.framework, "Web Server (:3000)")

        // Vite
        let viteData = inspector.inspect(
            pid: 999992,
            port: 5173,
            processName: "vite",
            category: .development
        )
        XCTAssertEqual(viteData.framework, "Vite")

        // Redis
        let redisData = inspector.inspect(
            pid: 999993,
            port: 6379,
            processName: "redis-server",
            category: .development
        )
        XCTAssertEqual(redisData.framework, "Redis")

        // PostgreSQL
        let pgData = inspector.inspect(
            pid: 999994,
            port: 5432,
            processName: "postgres",
            category: .development
        )
        XCTAssertEqual(pgData.framework, "PostgreSQL")

        // AirPlay Receiver
        let airplayData = inspector.inspect(
            pid: 999995,
            port: 5000,
            processName: "ControlCenter",
            category: .systemDaemon
        )
        XCTAssertEqual(airplayData.framework, "AirPlay Receiver")
    }

    func testRecommendationForSystemDaemons() {
        let inspector = ProcessDetailsInspector()
        let data = inspector.inspect(
            pid: 1,
            port: 5353,
            processName: "mDNSResponder",
            category: .systemDaemon
        )

        XCTAssertFalse(data.isOrphan)
        XCTAssertEqual(data.recommendation, .systemProtected(reason: "Serviço essencial do macOS"))
        XCTAssertFalse(data.recommendation.isRecommendedToKill)
        XCTAssertEqual(data.recommendation.badgeLabel, "Sistema")
    }

    func testRecommendationForPersistentDatabases() {
        let inspector = ProcessDetailsInspector()
        let data = inspector.inspect(
            pid: 999996,
            port: 6379,
            processName: "redis-server",
            category: .development
        )

        XCTAssertFalse(data.isOrphan)
        XCTAssertEqual(data.recommendation, .active(reason: "Base de dados ou serviço em background"))
        XCTAssertFalse(data.recommendation.isRecommendedToKill)
        XCTAssertEqual(data.recommendation.badgeLabel, "DB")
    }

    func testActivePortFormattedUptime() {
        let recentPort = ActivePort(
            port: 3000,
            pid: 1234,
            processName: "node",
            user: "dev",
            protocols: ["IPv4"],
            category: .development,
            uptimeSeconds: 45
        )
        XCTAssertEqual(recentPort.formattedUptime, "< 1m")

        let minsPort = ActivePort(
            port: 3000,
            pid: 1234,
            processName: "node",
            user: "dev",
            protocols: ["IPv4"],
            category: .development,
            uptimeSeconds: 720 // 12 min
        )
        XCTAssertEqual(minsPort.formattedUptime, "12m")

        let hoursPort = ActivePort(
            port: 3000,
            pid: 1234,
            processName: "node",
            user: "dev",
            protocols: ["IPv4"],
            category: .development,
            uptimeSeconds: 14400 // 4h
        )
        XCTAssertEqual(hoursPort.formattedUptime, "4h")

        let daysPort = ActivePort(
            port: 3000,
            pid: 1234,
            processName: "node",
            user: "dev",
            protocols: ["IPv4"],
            category: .development,
            uptimeSeconds: 259200 // 3d
        )
        XCTAssertEqual(daysPort.formattedUptime, "3d")
    }

    func testActivePortDisplayTitleAndAbbreviation() {
        let portWithFrameworkAndProject = ActivePort(
            port: 3000,
            pid: 1234,
            processName: "node",
            user: "dev",
            protocols: ["IPv4"],
            category: .development,
            projectOrAppName: "my-shop",
            workingDirectory: "/Users/developer/Projects/my-shop",
            framework: "Next.js"
        )

        XCTAssertEqual(portWithFrameworkAndProject.displayTitle, "Next.js • my-shop")

        let portWithOnlyProject = ActivePort(
            port: 8080,
            pid: 5678,
            processName: "python3",
            user: "dev",
            protocols: ["IPv4"],
            category: .development,
            projectOrAppName: "backend-api"
        )
        XCTAssertEqual(portWithOnlyProject.displayTitle, "backend-api (python3)")

        let plainPort = ActivePort(
            port: 4000,
            pid: 9999,
            processName: "elixir",
            user: "dev",
            protocols: ["IPv4"],
            category: .development
        )
        XCTAssertEqual(plainPort.displayTitle, "elixir")
    }

    func testLiveProcessInspectionOnCurrentProcess() async {
        let currentPid = getpid()
        let port = ActivePort(
            port: 8888,
            pid: currentPid,
            processName: "swift-frontend",
            user: "developer",
            protocols: ["IPv4"],
            category: .development
        )

        let inspector = ProcessDetailsInspector()
        let enriched = await inspector.enrich(ports: [port])

        XCTAssertEqual(enriched.count, 1)
        let result = enriched[0]
        XCTAssertEqual(result.pid, currentPid)
        XCTAssertNotNil(result.workingDirectory)
        XCTAssertNotNil(result.uptimeSeconds)
        XCTAssertNotNil(result.parentPid)
    }
}
