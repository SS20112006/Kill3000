import SwiftUI
import Kill3000Engine

/// Filter bar providing search input and a category segment picker
/// adhering strictly to Apple Human Interface Guidelines and WCAG AA contrast.
public struct FilterBarView: View {
    @Binding public var searchText: String
    private var customCategoryBinding: Binding<PortFilterCategory>?
    private var legacyShowAllPorts: Binding<Bool>?

    public let myPortsCount: Int
    public let devCount: Int
    public let suggestedCount: Int
    public let totalCount: Int

    @FocusState private var isSearchFocused: Bool

    /// Modern initializer using `PortFilterCategory` (.myPorts, .dev, .suggested, .all).
    public init(
        searchText: Binding<String>,
        filterCategory: Binding<PortFilterCategory>,
        myPortsCount: Int = 0,
        devCount: Int = 0,
        suggestedCount: Int = 0,
        totalCount: Int = 0
    ) {
        self._searchText = searchText
        self.customCategoryBinding = filterCategory
        self.legacyShowAllPorts = nil
        self.myPortsCount = myPortsCount
        self.devCount = devCount
        self.suggestedCount = suggestedCount
        self.totalCount = totalCount
    }

    /// Convenience initializer without `myPortsCount` for backward compatibility.
    public init(
        searchText: Binding<String>,
        filterCategory: Binding<PortFilterCategory>,
        devCount: Int,
        suggestedCount: Int,
        totalCount: Int
    ) {
        self.init(
            searchText: searchText,
            filterCategory: filterCategory,
            myPortsCount: 0,
            devCount: devCount,
            suggestedCount: suggestedCount,
            totalCount: totalCount
        )
    }

    /// Legacy compatibility initializer using `showAllPorts: Binding<Bool>`.
    public init(
        searchText: Binding<String>,
        showAllPorts: Binding<Bool>,
        devCount: Int = 0,
        totalCount: Int = 0
    ) {
        self._searchText = searchText
        self.customCategoryBinding = nil
        self.legacyShowAllPorts = showAllPorts
        self.myPortsCount = 0
        self.devCount = devCount
        self.suggestedCount = 0
        self.totalCount = totalCount
    }

    private var activeCategoryBinding: Binding<PortFilterCategory> {
        if let binding = customCategoryBinding {
            return binding
        }
        if let legacy = legacyShowAllPorts {
            return Binding<PortFilterCategory>(
                get: { legacy.wrappedValue ? .all : .dev },
                set: { legacy.wrappedValue = ($0 == .all) }
            )
        }
        return .constant(.dev)
    }

    /// Compatibility property for test inspections.
    public var showAllPorts: Bool {
        activeCategoryBinding.wrappedValue == .all
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Modern compact search input field with SF Symbol icon and clear button
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundStyle(isSearchFocused ? .primary : .secondary)
                    .padding(.leading, 8)
                    .accessibilityHidden(true)

                TextField("Filtrar portas, processos...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .tracking(0.1) // SF Pro Text optical tracking
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Procurar portas ativas")

                if !searchText.isEmpty {
                    Button(action: {
                        withAnimation(.snappy(duration: 0.15)) {
                            searchText = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 6)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 28, minHeight: 28)
                    .contentShape(Rectangle())
                    .help("Limpar pesquisa")
                    .accessibilityLabel("Limpar pesquisa")
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                } else {
                    Spacer()
                        .frame(width: 4)
                }
            }
            .frame(height: 28)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        isSearchFocused ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.1),
                        lineWidth: 1
                    )
            )
            .animation(.snappy(duration: 0.18), value: isSearchFocused)

            // Segmented picker for category filtering with live counters inline
            Picker("Categoria", selection: activeCategoryBinding) {
                Text("Minhas (\(myPortsCount))").tag(PortFilterCategory.myPorts)
                Text("Dev (\(devCount))").tag(PortFilterCategory.dev)
                if suggestedCount > 0 {
                    Text("Sugeridas (\(suggestedCount))").tag(PortFilterCategory.suggested)
                } else {
                    Text("Sugeridas").tag(PortFilterCategory.suggested)
                }
                Text("Todas (\(totalCount))").tag(PortFilterCategory.all)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
            .accessibilityLabel("Filtrar por categoria de portas")
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }
}
