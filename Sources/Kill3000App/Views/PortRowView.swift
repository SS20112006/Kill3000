import SwiftUI
import AppKit
import Kill3000Engine

/// Individual row view displaying active port details, project context, and action buttons.
/// Complies with Apple Human Interface Guidelines:
/// - SF Pro Text (<= 19pt) with optical tracking (0.1).
/// - Crisp monospaced port numbers for instant readability.
/// - Uncluttered, minimalist 2-line layout preventing text collisions.
/// - Secondary actions (Browser & Finder) reveal on hover, keeping the list peaceful while scrolling.
/// - Ergonomic 44x44pt hit targets for interactive elements.
/// - Clear visual recommendations (Orphan / Idle / Active / System).
/// - Full right-click context menu for quick power-user actions.
public struct PortRowView: View {
    public let port: ActivePort
    public let onOpenInBrowser: (Int) -> Void
    public let onKill: (ActivePort) -> Void
    public let onOpenFolder: ((String) -> Void)?

    @State private var isHovered: Bool = false
    @State private var isFolderHovered: Bool = false
    @State private var isBrowserHovered: Bool = false
    @State private var isKillHovered: Bool = false

    public init(
        port: ActivePort,
        onOpenInBrowser: @escaping (Int) -> Void,
        onKill: @escaping (ActivePort) -> Void,
        onOpenFolder: ((String) -> Void)? = nil
    ) {
        self.port = port
        self.onOpenInBrowser = onOpenInBrowser
        self.onKill = onKill
        self.onOpenFolder = onOpenFolder
    }

    public var body: some View {
        HStack(spacing: 8) {
            // High-visibility monospaced port badge
            Text(":\(port.port)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            // Main metadata column: strictly two clean lines
            VStack(alignment: .leading, spacing: 2) {
                // Line 1: Runtime Icon, Process/Framework Name, Recommendation Badge
                HStack(spacing: 5) {
                    Image(systemName: runtimeIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(iconColor)
                        .accessibilityHidden(true)

                    Text(port.displayTitle)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .tracking(0.1) // SF Pro Text optical tracking
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)

                    // Recommendation / Status Badge (Compact & Fixed Size)
                    statusBadge
                }

                // Line 2: Minimal single-line subtitle (PID • Uptime • Project Folder)
                Text(port.compactSubtitle)
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .tracking(0.1) // SF Pro Text
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            // Actions Area
            HStack(spacing: 2) {
                // Secondary actions: revealed smoothly on row hover
                if isHovered {
                    HStack(spacing: 2) {
                        // Open Project Directory in Finder (if path available)
                        if let folder = port.workingDirectory, let onOpenFolder = onOpenFolder {
                            Button(action: { onOpenFolder(folder) }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isFolderHovered ? Color.primary.opacity(0.10) : Color.clear)
                                        .frame(width: 26, height: 26)

                                    Image(systemName: "folder")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(isFolderHovered ? .primary : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(minWidth: 32, minHeight: 32)
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                withAnimation(.snappy(duration: 0.12)) {
                                    isFolderHovered = hovering
                                }
                            }
                            .help("Revelar pasta no Finder (\(folder))")
                            .accessibilityLabel("Abrir pasta do projeto no Finder")
                        }

                        // Open in Default Web Browser
                        Button(action: { onOpenInBrowser(port.port) }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isBrowserHovered ? Color.primary.opacity(0.10) : Color.clear)
                                    .frame(width: 26, height: 26)

                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(isBrowserHovered ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(minWidth: 32, minHeight: 32)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            withAnimation(.snappy(duration: 0.12)) {
                                isBrowserHovered = hovering
                            }
                        }
                        .help("Abrir http://localhost:\(port.port) no browser")
                        .accessibilityLabel("Abrir porta \(port.port) no browser")
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                // Primary Destructive Kill Button (Always Visible)
                Button(role: .destructive, action: { onKill(port) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))

                        Text("Kill")
                            .font(.system(size: 11, weight: .semibold, design: .default))
                            .tracking(0.1) // SF Pro Text
                    }
                    .foregroundStyle(killButtonColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        killButtonColor.opacity(isKillHovered ? 0.22 : (port.recommendation.isRecommendedToKill ? 0.16 : 0.10)),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                killButtonColor.opacity(isKillHovered ? 0.55 : (port.recommendation.isRecommendedToKill ? 0.40 : 0.22)),
                                lineWidth: port.recommendation.isRecommendedToKill ? 1.5 : 1
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
                .help(port.recommendation.reasonDescription)
                .accessibilityLabel("Terminar processo na porta \(port.port)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.regularMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    isHovered
                        ? Color.accentColor.opacity(0.35)
                        : (port.recommendation.isRecommendedToKill ? Color.orange.opacity(0.35) : Color.primary.opacity(0.06)),
                    lineWidth: 1
                )
        )
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.18)) {
                isHovered = hovering
            }
        }
        .help(detailedTooltip)
        .contextMenu {
            Button {
                onOpenInBrowser(port.port)
            } label: {
                Label("Abrir no Browser (localhost:\(port.port))", systemImage: "arrow.up.right.square")
            }

            if let folder = port.workingDirectory, let onOpenFolder = onOpenFolder {
                Button {
                    onOpenFolder(folder)
                } label: {
                    Label("Revelar Pasta no Finder", systemImage: "folder")
                }
            }

            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(":\(port.port)", forType: .string)
            } label: {
                Label("Copiar Porta (:\(port.port))", systemImage: "doc.on.doc")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(port.pid)", forType: .string)
            } label: {
                Label("Copiar PID (\(port.pid))", systemImage: "number")
            }

            Divider()

            Button(role: .destructive) {
                onKill(port)
            } label: {
                Label("Terminar Processo (Kill)", systemImage: "xmark.circle")
            }
        }
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        if port.recommendation.isRecommendedToKill {
            HStack(spacing: 3) {
                Image(systemName: port.isOrphan ? "exclamationmark.triangle.fill" : "clock.badge.exclamationmark")
                    .font(.system(size: 8, weight: .bold))
                Text(port.recommendation.badgeLabel)
                    .font(.system(size: 9, weight: .semibold, design: .default))
            }
            .foregroundStyle(Color.orange)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.35), lineWidth: 0.5)
            )
            .fixedSize()
            .help(port.recommendation.reasonDescription)
        } else if port.category == .systemDaemon {
            Text("Sistema")
                .font(.system(size: 9, weight: .medium, design: .default))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .fixedSize()
                .help("Serviço do sistema macOS")
        } else if port.recommendation.badgeLabel == "DB" {
            Text("DB")
                .font(.system(size: 9, weight: .medium, design: .default))
                .foregroundStyle(Color.blue)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .fixedSize()
                .help("Base de dados ou serviço em background")
        }
    }

    private var killButtonColor: Color {
        if port.category == .systemDaemon {
            return Color.orange
        }
        return Color.red
    }

    private var iconColor: Color {
        if port.category == .systemDaemon {
            return .secondary
        } else if port.recommendation.isRecommendedToKill {
            return .orange
        }
        return .primary
    }

    private var detailedTooltip: String {
        var lines: [String] = [
            "Porta: :\(port.port)",
            "Processo: \(port.processName) (PID \(port.pid))"
        ]
        if let title = port.framework ?? port.projectOrAppName {
            lines.append("Framework / Projeto: \(title)")
        }
        if let cwd = port.workingDirectory {
            lines.append("Diretoria: \(cwd)")
        }
        if let uptime = port.formattedUptime {
            lines.append("Uptime: \(uptime)")
        }
        let protos = port.protocols.sorted().joined(separator: ", ")
        lines.append("Protocolos: \(protos)")
        lines.append("Recomendação: \(port.recommendation.reasonDescription)")
        return lines.joined(separator: "\n")
    }

    /// Selects an appropriate SF Symbol icon representing the process runtime or framework.
    private var runtimeIcon: String {
        let name = "\(port.processName) \(port.framework ?? "")".lowercased()

        if port.category == .systemDaemon {
            return "shield.fill"
        }

        if name.contains("next") || name.contains("vite") || name.contains("turbopack") || name.contains("astro") {
            return "bolt.fill"
        } else if name.contains("node") || name.contains("bun") || name.contains("deno") {
            return "curlybraces"
        } else if name.contains("fastapi") || name.contains("uvicorn") || name.contains("python") || name.contains("django") || name.contains("flask") {
            return "chevron.left.forwardslash.chevron.right"
        } else if name.contains("go") || name.contains("air") {
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
