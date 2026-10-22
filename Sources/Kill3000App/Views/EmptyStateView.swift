import SwiftUI

/// Clean, elevated empty state view displayed when no listening ports are active or matched.
/// Conforms to Apple Human Interface Guidelines visual rhythm, San Francisco typography,
/// and WCAG AA contrast.
public struct EmptyStateView: View {
    public let isFiltered: Bool
    public let onClearFilter: (() -> Void)?

    @State private var isButtonHovered: Bool = false

    public init(isFiltered: Bool = false, onClearFilter: (() -> Void)? = nil) {
        self.isFiltered = isFiltered
        self.onClearFilter = onClearFilter
    }

    public var body: some View {
        VStack(spacing: 14) {
            // Hero Icon with layered visual depth
            if isFiltered {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.green, Color.green.opacity(0.18))
                    .accessibilityHidden(true)
            }

            // Descriptive Copy
            VStack(spacing: 5) {
                Text(isFiltered ? "No Matching Ports" : "All Clear")
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .tracking(-0.1) // SF Pro Text
                    .foregroundStyle(.primary)

                Text(isFiltered
                     ? "No listening ports match your filter or search criteria."
                     : "No active development servers currently listening on localhost.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .tracking(0.1) // SF Pro Text
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
            }

            // Contextual Action / Helpful Guidance
            if isFiltered, let onClearFilter {
                Button(action: onClearFilter) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 11, weight: .medium))
                        Text("Reset Filter")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .tracking(0.1)
                    }
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Color.accentColor.opacity(isButtonHovered ? 0.16 : 0.08),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44) // 44x44pt touch footprint
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.snappy(duration: 0.15)) {
                        isButtonHovered = hovering
                    }
                }
                .accessibilityLabel("Reset active filter and clear search")
            } else if !isFiltered {
                HStack(spacing: 5) {
                    Image(systemName: "terminal")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)

                    Text("Run npm run dev, vite, or cargo run to inspect")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .tracking(0.1)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
    }
}
