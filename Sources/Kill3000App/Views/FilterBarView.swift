import SwiftUI

/// Filter bar providing search input and a category segment picker
/// adhering strictly to Apple Human Interface Guidelines and WCAG AA contrast.
public struct FilterBarView: View {
    @Binding public var searchText: String
    @Binding public var showAllPorts: Bool

    public init(searchText: Binding<String>, showAllPorts: Binding<Bool>) {
        self._searchText = searchText
        self._showAllPorts = showAllPorts
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Modern search input field with SF Symbol icon and clear button
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
                    .accessibilityHidden(true)

                TextField("Search port or process...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .tracking(0.1) // SF Pro Text optical tracking
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Search active ports")

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44) // 44x44pt interactive hit target
                    .contentShape(Rectangle())
                    .help("Clear search text")
                    .accessibilityLabel("Clear search")
                }
            }
            .frame(minHeight: 34)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )

            // Segmented picker for category filtering
            Picker("Port Category", selection: $showAllPorts) {
                Text("Dev Servers").tag(false)
                Text("All Ports").tag(true)
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
