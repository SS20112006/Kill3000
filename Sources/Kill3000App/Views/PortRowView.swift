import SwiftUI
import Kill3000Engine

/// Individual row view displaying active port details and action buttons.
/// Complies with Apple Human Interface Guidelines:
/// - SF Pro Text (<= 19pt) with optical tracking.
/// - Crisp monospaced port numbers for high legibility.
/// - Ergonomic 44x44pt touch/click hit targets.
/// - Tactile hover and sensory feedback.
/// - Semantic vibrancy materials (.regularMaterial, .thinMaterial).
public struct PortRowView: View {
    public let port: ActivePort
    public let onOpenInBrowser: (Int) -> Void
    public let onKill: (ActivePort) -> Void

    @State private var isHovered: Bool = false
    @State private var isBrowserHovered: Bool = false
    @State private var isKillHovered: Bool = false

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
        HStack(spacing: 12) {
            // Port badge & process identification
            HStack(spacing: 8) {
                // High-visibility monospaced port badge
                Text(":\(port.port)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    // Process Name with runtime SF Symbol
                    HStack(spacing: 5) {
                        Image(systemName: runtimeIcon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)

                        Text(port.processName)
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .tracking(0.1) // SF Pro Text
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if port.category == .systemDaemon {
                            Text("System")
                                .font(.system(size: 9, weight: .medium, design: .default))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
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
            }

            Spacer()

            // Interactive Actions (Strict 44x44pt minimum footprint)
            HStack(spacing: 6) {
                // Open in browser button
                Button(action: { onOpenInBrowser(port.port) }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isBrowserHovered ? Color.primary.opacity(0.08) : Color.clear)
                            .frame(width: 32, height: 32)

                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isBrowserHovered ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44) // 44x44pt touch footprint
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.snappy(duration: 0.15)) {
                        isBrowserHovered = hovering
                    }
                }
                .help("Open http://localhost:\(port.port) in default browser")
                .accessibilityLabel("Open port \(port.port) in browser")

                // Destructive / Warning Kill button
                Button(role: .destructive, action: { onKill(port) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))

                        Text("Kill")
                            .font(.system(size: 11, weight: .semibold, design: .default))
                            .tracking(0.1) // SF Pro Text
                    }
                    .foregroundStyle(isSystemDaemon ? Color.orange : Color.red)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        (isSystemDaemon ? Color.orange : Color.red)
                            .opacity(isKillHovered ? 0.22 : 0.12),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                (isSystemDaemon ? Color.orange : Color.red)
                                    .opacity(isKillHovered ? 0.5 : 0.3),
                                lineWidth: 1
                            )
                    )
                    .scaleEffect(isKillHovered ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44) // 44x44pt touch footprint
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.snappy(duration: 0.15)) {
                        isKillHovered = hovering
                    }
                }
                .help(isSystemDaemon
                    ? "Warning: Terminate macOS system daemon \(port.processName) (PID \(port.pid))"
                    : "Terminate process \(port.processName) (PID \(port.pid))")
                .accessibilityLabel("Kill process on port \(port.port)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isHovered ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.18)) {
                isHovered = hovering
            }
        }
    }

    private var isSystemDaemon: Bool {
        port.category == .systemDaemon
    }

    /// Selects an appropriate SF Symbol icon representing the process runtime.
    private var runtimeIcon: String {
        let name = port.processName.lowercased()

        if port.category == .systemDaemon {
            return "shield.fill"
        }

        if name.contains("node") || name.contains("bun") || name.contains("deno") || name.contains("npm") || name.contains("yarn") {
            return "curlybraces"
        } else if name.contains("vite") || name.contains("next") || name.contains("webpack") || name.contains("turbopack") || name.contains("astro") {
            return "bolt.fill"
        } else if name.contains("python") || name.contains("uvicorn") || name.contains("gunicorn") || name.contains("flask") || name.contains("django") {
            return "chevron.left.forwardslash.chevron.right"
        } else if name.contains("go") {
            return "shippingbox.fill"
        } else if name.contains("cargo") || name.contains("rust") {
            return "gearshape.2.fill"
        } else if name.contains("ruby") || name.contains("rails") || name.contains("puma") {
            return "diamond.fill"
        } else if name.contains("docker") {
            return "cube.fill"
        } else if name.contains("postgres") || name.contains("redis") || name.contains("mongo") || name.contains("mysql") {
            return "cylinder.split.1x2.fill"
        } else if name.contains("java") {
            return "cup.and.saucer.fill"
        }

        return "network"
    }
}
