import SwiftUI
import AppKit
import Kill3000Engine

/// Full-featured macOS Dashboard window for Kill3000.
/// Complies with Apple Human Interface Guidelines:
/// - SF Pro Display for headers (>= 20pt) and SF Pro Text for labels (<= 19pt).
/// - Dynamic WCAG AA contrast ratios (>= 4.5:1).
/// - Native macOS semantic vibrancy materials (.ultraThinMaterial, .regularMaterial).
/// - Comprehensive process forensics (PID, PPID, CWD, full arguments, uptime, safety analysis).
/// - Direct one-click actions: Browser, Finder, and Terminate.
public struct DashboardView: View {
    @Bindable public var viewModel: PortListViewModel

    @State private var selectedPortId: String? = nil
    @State private var dashboardFilterText: String = ""
    @State private var dashboardCategory: PortFilterCategory = .all
    @State private var isRefreshing: Bool = false

    public init(viewModel: PortListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Dashboard Header & Metric Cards
            headerMetricsBar

            Divider()
                .opacity(0.3)

            // Search and Filter Bar
            dashboardFilterBar

            Divider()
                .opacity(0.3)

            // Main Table Area & Detail Inspector Split
            HSplitView {
                // Left / Main: Comprehensive Ports Table
                portsTableView
                    .frame(minWidth: 500, maxWidth: .infinity)

                // Right: Process Forensic Detail Inspector
                if let selectedPort = selectedPort {
                    portInspectorView(port: selectedPort)
                        .frame(minWidth: 260, maxWidth: 360)
                        .background(.regularMaterial)
                }
            }
            .frame(maxHeight: .infinity)

            Divider()
                .opacity(0.3)

            // Bottom Status Bar
            dashboardFooterBar
        }
        .frame(minWidth: 780, minHeight: 480)
        .background(.ultraThinMaterial)
    }

    // MARK: - Selected Port Helper

    private var selectedPort: ActivePort? {
        guard let id = selectedPortId else {
            return displayedPorts.first
        }
        return viewModel.ports.first(where: { $0.id == id }) ?? displayedPorts.first
    }

    private var displayedPorts: [ActivePort] {
        let query = dashboardFilterText.trimmingCharacters(in: .whitespacesAndNewlines)

        return viewModel.ports.filter { port in
            // Category filter
            switch dashboardCategory {
            case .dev:
                if port.category != .development { return false }
            case .suggested:
                if !port.recommendation.isRecommendedToKill { return false }
            case .all:
                break
            }

            guard !query.isEmpty else { return true }

            let matchesPort = String(port.port).localizedCaseInsensitiveContains(query)
            let matchesProcess = port.processName.localizedCaseInsensitiveContains(query)
            let matchesPid = String(port.pid).contains(query)
            let matchesProject = port.projectOrAppName?.localizedCaseInsensitiveContains(query) ?? false
            let matchesFramework = port.framework?.localizedCaseInsensitiveContains(query) ?? false
            let matchesPath = port.workingDirectory?.localizedCaseInsensitiveContains(query) ?? false

            return matchesPort || matchesProcess || matchesPid || matchesProject || matchesFramework || matchesPath
        }
    }

    // MARK: - Header Metrics Bar

    private var headerMetricsBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "network.badge.shield.half.filled")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.tint)

                    Text("Kill3000 Dashboard")
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button(action: {
                    Task {
                        isRefreshing = true
                        await viewModel.refresh()
                        isRefreshing = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)

                        Text("Atualizar")
                            .font(.system(size: 11, weight: .medium, design: .default))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("r", modifiers: .command)
                .help("Atualizar lista de portas (⌘R)")
            }

            // 4 KPI Summary Cards
            HStack(spacing: 12) {
                metricCard(
                    title: "Portas Ativas",
                    count: viewModel.totalPortsCount,
                    icon: "network",
                    color: .primary,
                    isSelected: dashboardCategory == .all,
                    action: { dashboardCategory = .all }
                )

                metricCard(
                    title: "Servidores Dev",
                    count: viewModel.devPortsCount,
                    icon: "hammer.fill",
                    color: .accentColor,
                    isSelected: dashboardCategory == .dev,
                    action: { dashboardCategory = .dev }
                )

                metricCard(
                    title: "Sugeridas a Fechar",
                    count: viewModel.suggestedPortsCount,
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    isSelected: dashboardCategory == .suggested,
                    highlight: viewModel.suggestedPortsCount > 0,
                    action: { dashboardCategory = .suggested }
                )

                metricCard(
                    title: "Sistema macOS",
                    count: viewModel.totalPortsCount - viewModel.devPortsCount,
                    icon: "shield.fill",
                    color: .secondary,
                    isSelected: false,
                    action: { dashboardCategory = .all }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private func metricCard(
        title: String,
        count: Int,
        icon: String,
        color: Color,
        isSelected: Bool,
        highlight: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(count)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)

                    Text(title)
                        .font(.system(size: 10, weight: .medium, design: .default))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                isSelected ? Color.accentColor.opacity(0.12) : (highlight ? Color.orange.opacity(0.12) : Color.primary.opacity(0.04)),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.4) : (highlight ? Color.orange.opacity(0.4) : Color.primary.opacity(0.08)),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dashboard Filter Bar

    private var dashboardFilterBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Filtrar por porta, processo, PID, diretoria...", text: $dashboardFilterText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .tracking(0.1)

                if !dashboardFilterText.isEmpty {
                    Button(action: { dashboardFilterText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Picker("Filtro", selection: $dashboardCategory) {
                Text("Todas (\(viewModel.totalPortsCount))").tag(PortFilterCategory.all)
                Text("Dev (\(viewModel.devPortsCount))").tag(PortFilterCategory.dev)
                Text("Sugeridas (\(viewModel.suggestedPortsCount))").tag(PortFilterCategory.suggested)
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Ports Table View

    private var portsTableView: some View {
        Group {
            if displayedPorts.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Nenhuma porta encontrada")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        // Table Header
                        HStack(spacing: 8) {
                            Text("PORTA")
                                .frame(width: 65, alignment: .leading)
                            Text("TÍTULO / PROJETO")
                                .frame(minWidth: 140, alignment: .leading)
                            Text("PROCESSO")
                                .frame(width: 100, alignment: .leading)
                            Text("ESTADO")
                                .frame(width: 85, alignment: .leading)
                            Text("UPTIME")
                                .frame(width: 60, alignment: .leading)
                            Spacer()
                            Text("AÇÕES")
                                .frame(width: 110, alignment: .trailing)
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.thinMaterial)

                        // Table Rows
                        ForEach(displayedPorts) { port in
                            dashboardRow(port: port)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func dashboardRow(port: ActivePort) -> some View {
        let isSelected = selectedPortId == port.id

        return HStack(spacing: 8) {
            // Port Badge
            Text(":\(port.port)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.tint)
                .frame(width: 65, alignment: .leading)

            // Title & Framework
            HStack(spacing: 4) {
                Text(port.displayTitle)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(minWidth: 140, alignment: .leading)

            // Process & PID
            Text("\(port.processName) (\(port.pid))")
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)

            // Status Badge
            tableStatusBadge(port: port)
                .frame(width: 85, alignment: .leading)

            // Uptime
            Text(port.formattedUptime ?? "-")
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            Spacer()

            // Row Action Buttons
            HStack(spacing: 6) {
                if let folder = port.workingDirectory {
                    Button(action: { viewModel.openProjectFolder(path: folder) }) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Revelar pasta no Finder")
                }

                Button(action: { viewModel.openInBrowser(port: port.port) }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Abrir no Browser")

                Button(role: .destructive, action: {
                    Task {
                        await viewModel.kill(port: port)
                    }
                }) {
                    Text("Kill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Terminar processo na porta \(port.port)")
            }
            .frame(width: 110, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isSelected ? Color.accentColor.opacity(0.14) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedPortId = port.id
        }
    }

    @ViewBuilder
    private func tableStatusBadge(port: ActivePort) -> some View {
        if port.recommendation.isRecommendedToKill {
            Text(port.recommendation.badgeLabel)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else if port.category == .systemDaemon {
            Text("Sistema")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            Text("Ativo")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.green)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    // MARK: - Port Inspector View

    private func portInspectorView(port: ActivePort) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header of Inspector
                VStack(alignment: .leading, spacing: 4) {
                    Text("Detalhes do Processo")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(":\(port.port) • \(port.displayTitle)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                }

                // Recommendation Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: port.recommendation.isRecommendedToKill ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                            .foregroundStyle(port.recommendation.isRecommendedToKill ? .orange : .green)

                        Text("Diagnóstico de Segurança")
                            .font(.system(size: 12, weight: .bold))
                    }

                    Text(port.recommendation.reasonDescription)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(
                    (port.recommendation.isRecommendedToKill ? Color.orange : Color.green).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

                // Key Forensic Fields
                VStack(alignment: .leading, spacing: 8) {
                    inspectorField(label: "PID", value: "\(port.pid)")
                    if let ppid = port.parentPid {
                        inspectorField(label: "PID Pai (PPID)", value: "\(ppid)")
                    }
                    inspectorField(label: "Utilizador", value: port.user)
                    if let uptime = port.formattedUptime {
                        inspectorField(label: "Tempo em Execução", value: uptime)
                    }
                    inspectorField(label: "Protocolos", value: port.protocols.sorted().joined(separator: ", "))
                    if let framework = port.framework {
                        inspectorField(label: "Framework", value: framework)
                    }
                    if let cwd = port.workingDirectory {
                        inspectorField(label: "Diretoria (CWD)", value: cwd, isPath: true)
                    }
                    if let exec = port.commandPath {
                        inspectorField(label: "Executável", value: exec, isPath: true)
                    }
                    if let args = port.commandArgs {
                        inspectorField(label: "Argumentos CLI", value: args)
                    }
                }

                Spacer(minLength: 16)

                // Bottom Inspector Kill Button
                Button(role: .destructive, action: {
                    Task {
                        await viewModel.kill(port: port)
                    }
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "xmark.circle.fill")
                        Text("Terminar Processo na Porta :\(port.port)")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
        }
    }

    private func inspectorField(label: String, value: String, isPath: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 11, weight: .regular, design: isPath ? .monospaced : .default))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Dashboard Footer Bar

    private var dashboardFooterBar: some View {
        HStack {
            Text("\(displayedPorts.count) de \(viewModel.totalPortsCount) portas listadas")
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundStyle(.secondary)

            Spacer()

            if viewModel.suggestedPortsCount > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    Text("\(viewModel.suggestedPortsCount) recomendadas a fechar")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.thinMaterial)
    }
}
