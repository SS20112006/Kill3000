import SwiftUI
import Kill3000Engine

/// Individual row view displaying active port details, project context, and action buttons.
/// Complies with Apple Human Interface Guidelines:
/// - SF Pro Text (<= 19pt) with optical tracking.
/// - Crisp monospaced port numbers for high legibility.
/// - Ergonomic 44x44pt touch/click hit targets for all interactive elements.
/// - Tactile hover states and sensory feedback.
/// - Semantic vibrancy materials (.regularMaterial, .thinMaterial, .ultraThinMaterial).
/// - Clear visual recommendations (Orphan / Idle / Active / System).
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
        HStack(spacing: 10) {
            // High-visibility monospaced port badge
            Text(":\(port.port)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            // Main metadata column
            VStack(alignment: .leading, spacing: 3) {
                // Header line: Icon, Framework/Project Name, Recommendation Badges, Uptime
                HStack(spacing: 5) {
                    Image(systemName: runtimeIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(iconColor)
                        .accessibilityHidden(true)

                    Text(port.displayTitle)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .tracking(0.1) // SF Pro Text
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Recommendation / Status Badges
                    statusBadge

                    // Relative Uptime
                    if let uptime = port.formattedUptime {
                        Text("• \(uptime)")
                            .font(.system(size: 10, weight: .medium, design: .default))
                            .foregroundStyle(.secondary)
                            .help("Em execução há \(uptime)")
                    }
                }

                // Subtitle line: Working directory or process arguments, PID, Protocols
                HStack(spacing: 5) {
                    if let path = port.abbreviatedPath {
                        Text(path)
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .tracking(0.1)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(port.workingDirectory ?? path)

                        Text("•")
                            .font(.system(size: 10, weight: .light))
                            .foregroundStyle(.tertiary)
                    }

                    Text("PID \(port.pid) (\(port.processName))")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .tracking(0.1)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    ForEach(Array(port.protocols.sorted()), id: \.self) { proto in
                        Text(proto)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 3.5)
                            .padding(.vertical, 1)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                }
            }

            Spacer(minLength: 4)

            // Interactive Actions (Strict 44x44pt minimum footprint per Apple HIG)
            HStack(spacing: 4) {
                // Open Project Directory in Finder (if available)
                if let folder = port.workingDirectory, let onOpenFolder = onOpenFolder {
                    Button(action: { onOpenFolder(folder) }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isFolderHovered ? Color.primary.opacity(0.08) : Color.clear)
                                .frame(width: 30, height: 30)

                            Image(systemName: "folder")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(isFolderHovered ? .primary : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.snappy(duration: 0.15)) {
                            isFolderHovered = hovering
                        }
                    }
                    .help("Revelar pasta do projeto no Finder (\(folder))")
                    .accessibilityLabel("Abrir pasta do projeto no Finder")
                }

                // Open in browser button
                Button(action: { onOpenInBrowser(port.port) }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isBrowserHovered ? Color.primary.opacity(0.08) : Color.clear)
                            .frame(width: 30, height: 30)

                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12, weight: .medium))
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
                .help("Abrir http://localhost:\(port.port) no browser padrão")
                .accessibilityLabel("Abrir porta \(port.port) no browser")

                // Destructive / Warning Kill button
                Button(role: .destructive, action: { onKill(port) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))

                        Text("Kill")
                            .font(.system(size: 11, weight: .semibold, design: .default))
                            .tracking(0.1) // SF Pro Text
                    }
                    .foregroundStyle(killButtonColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        killButtonColor.opacity(isKillHovered ? 0.22 : (port.isOrphan ? 0.16 : 0.10)),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                killButtonColor.opacity(isKillHovered ? 0.55 : (port.isOrphan ? 0.40 : 0.25)),
                                lineWidth: port.isOrphan ? 1.5 : 1
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
                    isHovered
                        ? Color.accentColor.opacity(0.35)
                        : (port.isOrphan ? Color.orange.opacity(0.25) : Color.primary.opacity(0.06)),
                    lineWidth: 1
                )
        )
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.18)) {
                isHovered = hovering
            }
        }
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        if port.category == .systemDaemon {
            Text("Sistema")
                .font(.system(size: 9, weight: .medium, design: .default))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .help("Serviço do sistema macOS")
        } else if port.isOrphan {
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8, weight: .bold))
                Text("Órfão")
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
            .help("Processo órfão: o terminal pai já fechou. Seguro limpar.")
        } else if port.recommendation.badgeLabel == "Inativo" {
            HStack(spacing: 3) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 8, weight: .bold))
                Text("Inativo (+24h)")
                    .font(.system(size: 9, weight: .medium, design: .default))
            }
            .foregroundStyle(Color.orange)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .help("Servidor ligado há mais de 24 horas sem atividade recente.")
        } else if port.recommendation.badgeLabel == "DB" {
            Text("Base de Dados")
                .font(.system(size: 9, weight: .medium, design: .default))
                .foregroundStyle(Color.blue)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .help("Base de dados ou daemon local em background.")
        }
    }

    private var killButtonColor: Color {
        if port.category == .systemDaemon {
            return Color.orange
        } else if port.isOrphan {
            return Color.red
        }
        return Color.red
    }

    private var iconColor: Color {
        if port.category == .systemDaemon {
            return .secondary
        } else if port.isOrphan {
            return .orange
        }
        return .primary
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
