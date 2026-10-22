import SwiftUI
import Foundation
import Darwin
import Kill3000Engine

/// Main application entrypoint for Kill3000.
/// Runs as a lightweight macOS MenuBarExtra application without a Dock icon,
/// or executes CLI commands when invoked with terminal arguments.
@main
public struct Kill3000App: App {
    @State private var viewModel: PortListViewModel

    public init() {
        if CLIHandler.isCLIInvocation() {
            Task {
                let handler = CLIHandler()
                let exitCode = await handler.execute()
                exit(exitCode)
            }
            dispatchMain()
        }
        _viewModel = State(initialValue: PortListViewModel())
    }

    public init(viewModel: PortListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some Scene {
        MenuBarExtra("Kill3000", systemImage: "network.badge.shield.half.filled") {
            PopoverContainerView(viewModel: viewModel)
                .onAppear {
                    viewModel.startPolling()
                }
                .onDisappear {
                    viewModel.stopPolling()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
