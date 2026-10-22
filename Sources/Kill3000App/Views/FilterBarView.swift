import SwiftUI

/// Filter bar providing search input and a category segment picker
/// adhering strictly to Apple Human Interface Guidelines and WCAG AA contrast.
public struct FilterBarView: View {
    @Binding public var searchText: String
    @Binding public var showAllPorts: Bool
    public let devCount: Int
    public let totalCount: Int

    @FocusState private var isSearchFocused: Bool

    public init(
        searchText: Binding<String>,
        showAllPorts: Binding<Bool>,
        devCount: Int = 0,
        totalCount: Int = 0
    ) {
        self._searchText = searchText
        self._showAllPorts = showAllPorts
        self.devCount = devCount
        self.totalCount = totalCount
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Modern search input field with SF Symbol icon and clear button
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(isSearchFocused ? .primary : .secondary)
                    .padding(.leading, 10)
                    .accessibilityHidden(true)

                TextField("Search port or process...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .tracking(0.1) // SF Pro Text optical tracking
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Search active ports")

                if !searchText.isEmpty {
                    Button(action: {
                        withAnimation(.snappy(duration: 0.15)) {
                            searchText = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 34) // 44pt touch footprint
                    .contentShape(Rectangle())
                    .help("Clear search text")
                    .accessibilityLabel("Clear search")
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                } else {
                    Spacer()
                        .frame(width: 4)
                }
            }
            .frame(height: 34)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSearchFocused ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.1),
                        lineWidth: 1
                    )
            )
            .animation(.snappy(duration: 0.18), value: isSearchFocused)

            // Segmented picker for category filtering with live counters
            Picker("Port Category", selection: $showAllPorts) {
                if devCount > 0 || totalCount > 0 {
                    Text("Dev (\(devCount))").tag(false)
                    Text("All (\(totalCount))").tag(true)
                } else {
                    Text("Dev Servers").tag(false)
                    Text("All Ports").tag(true)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.regular)
            .accessibilityLabel("Filter by port category")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
