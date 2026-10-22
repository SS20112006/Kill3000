import SwiftUI
import Kill3000Engine

/// Individual row view displaying active port details and action buttons.
/// Complies with Apple HIG ergonomics (min 44x44pt targets), San Francisco typography,
/// and semantic vibrancy materials.
public struct PortRowView: View {
    public let port: ActivePort
    public let onOpenInBrowser: (Int) -> Void
    public let onKill: (ActivePort) -> Void

    public init(
        port: ActivePort,
        onOpenInBrowser: @escaping (Int) -> Void,
        onKill: @escaping (ActivePort) -> Void
    ) {
        self.port = port
        self.onOpenInBrowser = onOpenInBrowser
        self.onKill = onKill
    }

    public var body: some View {
        HStack(spacing: 10) {
            // Port number & Process Information
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    // Monospaced port number for crisp tabular alignment
                    Text(":\(port.port)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)

                    // Process executable name
                    Text(port.processName)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .tracking(0.1) // SF Pro Text
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Subtle category badge if system daemon
                    if port.category == .systemDaemon {
                        Text("System")
                            .font(.system(size: 9, weight: .medium, design: .default))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }

                // Secondary metadata: PID, user, protocols
                HStack(spacing: 6) {
                    Text("PID \(port.pid) • \(port.user)")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .tracking(0.1) // SF Pro Text
                        .foregroundStyle(.secondary)

                    ForEach(Array(port.protocols.sorted()), id: \.self) { proto in
                        Text(proto)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                }
            }

            Spacer()

            // Interactive Actions (Strict 44x44pt minimum footprint)
            HStack(spacing: 4) {
                // Open in browser button
                Button(action: { onOpenInBrowser(port.port) }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44) // 44x44pt touch footprint
                .contentShape(Rectangle())
                .help("Open http://localhost:\(port.port) in default browser")
                .accessibilityLabel("Open port \(port.port) in browser")

                // Destructive Kill button
                Button(role: .destructive, action: { onKill(port) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Kill")
                            .font(.system(size: 11, weight: .semibold, design: .default))
                            .tracking(0.1) // SF Pro Text
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44) // 44x44pt touch footprint
                .contentShape(Rectangle())
                .help("Terminate process \(port.processName) (PID \(port.pid))")
                .accessibilityLabel("Kill process on port \(port.port)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
