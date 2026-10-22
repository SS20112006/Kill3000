import SwiftUI

/// Clean empty state view displayed when no listening ports are active or matched.
/// Conforms to Apple HIG visual rhythm, San Francisco typography, and WCAG AA contrast.
public struct EmptyStateView: View {
    public let isFiltered: Bool

    public init(isFiltered: Bool = false) {
        self.isFiltered = isFiltered
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isFiltered ? "magnifyingglass" : "checkmark.circle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(isFiltered ? AnyShapeStyle(.secondary) : AnyShapeStyle(.green))
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(isFiltered ? "No Matching Ports" : "All Clear")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .tracking(-0.1) // SF Pro Text
                    .foregroundStyle(.primary)

                Text(isFiltered
                     ? "No listening ports match your search criteria."
                     : "No active development servers currently listening on localhost.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .tracking(0.1) // SF Pro Text
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding(.vertical, 20)
        .accessibilityElement(children: .combine)
    }
}
