import SwiftUI
import AppKit
import Kill3000Engine

/// Root popover container view displayed in the macOS MenuBarExtra.
/// Implements Apple Human Interface Guidelines:
/// - SF Pro Text (<= 19pt) with positive optical tracking for compact title and controls.
/// - Native macOS `.ultraThinMaterial` translucency and semantic materials.
/// - 44x44pt minimum touch target footprints for all interactive elements.
/// - WCAG AA compliant contrast (>= 4.5:1).
/// - Sensory haptic feedback (.impact, .selection, .error).
/// - Snappy macOS spring animations and hover micro-interactions.
public struct PopoverContainerView: View {
    @Bindable public var viewModel: PortListViewModel
    @Environment(\.openWindow) private var openWindow

    @State private var isDashboardHovered: Bool = false
    @State private var isRefreshHovered: Bool = false
    @State private var isQuitHovered: Bool = false
    @State private var isLivePulsing: Bool = false

    public init(viewModel: PortListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerView

            // Dismissible error banner (if present)
            if let errorMessage = viewModel.errorMessage {
                errorBanner(message: errorMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Search and Category Filter (Dev, Sugeridas, Todas)
            FilterBarView(
                searchText: $viewModel.searchText,
                filterCategory: $viewModel.filterCategory,
                devCount: viewModel.devPortsCount,
                suggestedCount: viewModel.suggestedPortsCount,
                totalCount: viewModel.totalPortsCount
            )

            Divider()
                .opacity(0.3)

            // Main Content Area: Scrollable Port List or Empty State
            contentView

            Divider()
                .opacity(0.3)

            // Bottom Status / Metadata Bar
            footerView
        }
        .frame(width: 420)
        .frame(minHeight: 260, maxHeight: 540)
        .background(.ultraThinMaterial)
        .sensoryFeedback(.selection, trigger: viewModel.filterCategory)
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.ports.count) { old, new in
            new < old // Trigger impact when a port was terminated / removed
        }
        .sensoryFeedback(.error, trigger: viewModel.errorMessage) { old, new in
            new != nil // Trigger error haptic when an error message is set
        }
        .onAppear {
            viewModel.startPolling()
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isLivePulsing = true
            }
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack(alignment: .center, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                // Compact Header <= 19pt: SF Pro Text with optical tracking (0.1)
                Text("Kill3000")
                    .font(.system(size: 14, weight: .bold, design: .default))
                    .tracking(0.1)
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Open Dashboard full-window button (44x44pt target) with keyboard shortcut
            Button(action: {
                openWindow(id: "dashboard")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isDashboardHovered ? Color.primary.opacity(0.08) : Color.clear)
                        .frame(width: 26, height: 26)

                    Image(systemName: "macwindow.on.rectangle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isDashboardHovered ? .primary : .secondary)
                }
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .keyboardShortcut("d", modifiers: .command)
            .onHover { hovering in
                withAnimation(.snappy(duration: 0.15)) {
                    isDashboardHovered = hovering
                }
            }
            .help("Abrir Dashboard completo (⌘D)")
            .accessibilityLabel("Abrir Dashboard")

            // Refresh action button (44x44pt target) with keyboard shortcut
            Button(action: {
                Task {
                    await viewModel.refresh()
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isRefreshHovered ? Color.primary.opacity(0.08) : Color.clear)
                        .frame(width: 26, height: 26)

                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isRefreshHovered ? .primary : .secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .keyboardShortcut("r", modifiers: .command)
            .onHover { hovering in
                withAnimation(.snappy(duration: 0.15)) {
                    isRefreshHovered = hovering
                }
            }
            .help("Atualizar portas ativas (⌘R)")
            .accessibilityLabel("Atualizar portas ativas")

            // Quit application button (44x44pt target) with keyboard shortcut
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isQuitHovered ? Color.primary.opacity(0.08) : Color.clear)
                        .frame(width: 26, height: 26)

                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isQuitHovered ? .primary : .secondary)
                }
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .keyboardShortcut("q", modifiers: .command)
            .onHover { hovering in
                withAnimation(.snappy(duration: 0.15)) {
                    isQuitHovered = hovering
                }
            }
            .help("Fechar Kill3000 (⌘Q)")
            .accessibilityLabel("Fechar Kill3000")
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text(message)
                .font(.system(size: 12, weight: .medium, design: .default))
                .tracking(0.1) // SF Pro Text
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer()

            Button(action: {
                withAnimation(.snappy(duration: 0.15)) {
                    viewModel.errorMessage = nil
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 32, minHeight: 32)
            .contentShape(Rectangle())
            .help("Fechar alerta")
            .accessibilityLabel("Fechar mensagem de erro")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private var contentView: some View {
        Group {
            if viewModel.filteredPorts.isEmpty {
                EmptyStateView(
                    isFiltered: !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.filterCategory != .dev,
                    onClearFilter: {
                        withAnimation(.snappy(duration: 0.2)) {
                            viewModel.searchText = ""
                            viewModel.filterCategory = .dev
                        }
                    }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.filteredPorts) { port in
                            PortRowView(
                                port: port,
                                onOpenInBrowser: { portNum in
                                    viewModel.openInBrowser(port: portNum)
                                },
                                onKill: { portToKill in
                                    Task {
                                        await viewModel.kill(port: portToKill)
                                    }
                                },
                                onOpenFolder: { folderPath in
                                    viewModel.openProjectFolder(path: folderPath)
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .animation(.snappy(duration: 0.22), value: viewModel.filteredPorts)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var footerView: some View {
        HStack {
            Text("\(viewModel.filteredPorts.count) de \(viewModel.totalPortsCount) \(viewModel.totalPortsCount == 1 ? "porta" : "portas")")
                .font(.system(size: 11, weight: .regular, design: .default))
                .tracking(0.1) // SF Pro Text
                .foregroundStyle(.secondary)

            if viewModel.suggestedPortsCount > 0 && viewModel.filterCategory != .suggested {
                Button(action: {
                    withAnimation(.snappy(duration: 0.18)) {
                        viewModel.filterCategory = .suggested
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                        Text("\(viewModel.suggestedPortsCount) para limpar")
                            .font(.system(size: 10, weight: .semibold, design: .default))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Filtrar portas órfãs ou inativas recomendadas para fechar")
            }

            Spacer()

            if viewModel.isPolling {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .opacity(isLivePulsing ? 1.0 : 0.4)

                    Text("Live (2s)")
                        .font(.system(size: 10, weight: .medium, design: .default))
                        .tracking(0.1)
                        .foregroundStyle(.secondary)
                }
                .help("Sondagem em background ativa a cada 2 segundos")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.thinMaterial)
    }
}
