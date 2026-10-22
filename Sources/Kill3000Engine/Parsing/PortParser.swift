import Foundation

/// Deterministic parser for `/usr/sbin/lsof -iTCP -sTCP:LISTEN -n -P` output.
///
/// Features ReDoS-immune bounded regular expression matching, robust terminal noise
/// filtering, and dual-stack IPv4/IPv6 deduplication.
public struct PortParser: Sendable {
    /// Bounded regex for TCP LISTEN rows from lsof.
    ///
    /// Captures:
    /// 1. Command / Process Name
    /// 2. PID
    /// 3. User
    /// 4. IP Version (IPv4 or IPv6)
    /// 5. Port Number (1 to 5 digits)
    private static let listenRowRegex: NSRegularExpression = {
        let pattern = #"^(\S+)\s+(\d+)\s+(\S+)\s+\S+\s+(IPv[46])\s+\S+\s+\S+\s+TCP\s+(?:\[[0-9a-fA-F:]+\]|[\*0-9a-zA-Z.-]+):(\d{1,5})\s+\(LISTEN\)"#
        // This regex pattern is validated at compile time
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: pattern)
    }()

    public init() {}

    /// Static convenience method to parse raw lsof output into active ports.
    ///
    /// - Parameter output: The stdout string from `lsof`.
    /// - Returns: Deduplicated list of `ActivePort` records sorted ascending by port.
    public static func parse(_ output: String) -> [ActivePort] {
        PortParser().parse(output)
    }

    /// Parses raw lsof output into active ports.
    ///
    /// - Parameter output: The stdout string from `lsof`.
    /// - Returns: Deduplicated list of `ActivePort` records sorted ascending by port.
    public func parse(_ output: String) -> [ActivePort] {
        guard !output.isEmpty else { return [] }

        struct GroupKey: Hashable {
            let port: Int
            let pid: pid_t
        }

        struct GroupValue {
            let processName: String
            let user: String
            var protocols: Set<String>
        }

        var grouped: [GroupKey: GroupValue] = [:]

        // Process line by line to prevent any multi-line regex backtracking
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("COMMAND") || trimmed.hasPrefix("lsof:") {
                continue
            }

            let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            guard let match = Self.listenRowRegex.firstMatch(in: trimmed, options: [], range: nsRange),
                  match.numberOfRanges == 6 else {
                continue
            }

            guard let nameRange = Range(match.range(at: 1), in: trimmed),
                  let pidRange = Range(match.range(at: 2), in: trimmed),
                  let userRange = Range(match.range(at: 3), in: trimmed),
                  let protoRange = Range(match.range(at: 4), in: trimmed),
                  let portRange = Range(match.range(at: 5), in: trimmed) else {
                continue
            }

            let processName = String(trimmed[nameRange])
            let pidString = String(trimmed[pidRange])
            let user = String(trimmed[userRange])
            let proto = String(trimmed[protoRange])
            let portString = String(trimmed[portRange])

            guard let pid = pid_t(pidString), pid > 0,
                  let port = Int(portString), (1...65535).contains(port) else {
                continue
            }

            let key = GroupKey(port: port, pid: pid)
            if var existing = grouped[key] {
                existing.protocols.insert(proto)
                grouped[key] = existing
            } else {
                grouped[key] = GroupValue(
                    processName: processName,
                    user: user,
                    protocols: [proto]
                )
            }
        }

        return grouped.map { key, value in
            ActivePort(
                port: key.port,
                pid: key.pid,
                processName: value.processName,
                user: value.user,
                protocols: value.protocols,
                category: ProcessInspector.classify(processName: value.processName)
            )
        }
        .sorted { lhs, rhs in
            if lhs.port != rhs.port {
                return lhs.port < rhs.port
            }
            return lhs.pid < rhs.pid
        }
    }
}
