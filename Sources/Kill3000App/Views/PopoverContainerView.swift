import SwiftUI
import Kill3000Engine

/// Root popover container view displayed in the macOS MenuBarExtra.
/// Implements Apple Human Interface Guidelines:
/// - SF Pro Display (>= 20pt) with optical negative tracking for title.
/// - SF Pro Text (<= 19pt) with positive tracking for legibility.
/// - Native macOS `.ultraThinMaterial` translucency and semantic materials.
/// - 44x44pt minimum touch target footprints for all interactive elements.
/// - WCAG AA compliant contrast (>= 4.5:1).
/// - Sensory haptic feedback (.impact, .selection, .error).
public struct PopoverContainerView: View {
    @Bindable public var viewModel: PortListViewModel

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

            // Search and Category Filter
            FilterBarView(
                searchText: $viewModel.searchText,
                showAllPorts: $viewModel.showAllPorts
            )

            Divider()
                .opacity(0.4)

            // Main Content Area: Scrollable Port List or Empty State
            contentView

            Divider()
                .opacity(0.4)

            // Bottom Status / Metadata Bar
            footerView
        }
        .frame(width: 360)
        .frame(minHeight: 220, maxHeight: 480)
        .background(.ultraThinMaterial)
        .sensoryFeedback(.selection, trigger: viewModel.showAllPorts)
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.ports.count) { old, new in
            new < old // Trigger impact when a port was terminated / removed
        }
        .sensoryFeedback(.error, trigger: viewModel.errorMessage) { old, new in
            new != nil // Trigger error haptic when an error message is set
        }
        .onAppear {
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                // Header >= 20pt: SF Pro Display with optical tracking (-0.4)
                Text("Kill3000")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .tracking(-0.4)
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Refresh action button (44x44pt target)
            Button(action: {
                Task {
                    await viewModel.refresh()
                }
            }) {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .help("Refresh active ports")
            .accessibilityLabel("Refresh active ports")

            // Quit application button (44x44pt target)
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .help("Quit Kill3000")
            .accessibilityLabel("Quit Kill3000")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)

            Text(message)
                .font(.system(size: 12, weight: .medium, design: .default))
                .tracking(0.1) // SF Pro Text
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer()

            Button(action: {
                viewModel.errorMessage = nil
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .help("Dismiss alert")
            .accessibilityLabel("Dismiss error message")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.red.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private var contentView: some View {
        Group {
            if viewModel.filteredPorts.isEmpty {
                EmptyStateView(
                    isFiltered: !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || (!viewModel.showAllPorts && viewModel.ports.contains { $0.category != .development })
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
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var footerView: some View {
        HStack {
            Text("\(viewModel.filteredPorts.count) \(viewModel.filteredPorts.count == 1 ? "port" : "ports") listening")
                .font(.system(size: 11, weight: .regular, design: .default))
                .tracking(0.1) // SF Pro Text
                .foregroundStyle(.secondary)

            Spacer()

            if viewModel.isPolling {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)

                    Text("Live (2s)")
                        .font(.system(size: 10, weight: .medium, design: .default))
                        .tracking(0.1)
                        .foregroundStyle(.secondary)
                }
                .help("Background polling is active every 2 seconds")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }
}
