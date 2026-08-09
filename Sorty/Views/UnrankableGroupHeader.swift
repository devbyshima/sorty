import SwiftUI

/// Introduces the tracks the active Arrangement couldn't place.
///
/// The tracks below it were always here - nil sinks to the bottom in either
/// direction - but they arrived silently, showing a dash. A run of blank rows
/// with no explanation reads as a bug in the app rather than as data the
/// provider lacked, which is what this header exists to correct.
struct UnrankableGroupHeader: View {
    let group: UnrankableGroup

    @State private var expanded = false

    var body: some View {
        Button {
            withAnimation(.snappy) { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: group.reason.symbolName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(group.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                }

                Text(group.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(expanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(SortyTheme.surface)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(group.title)
        .accessibilityValue(group.detail)
        .accessibilityHint(expanded ? "Shortens the explanation." : "Reads the whole explanation.")
        .accessibilityAddTraits(.isHeader)
    }
}
