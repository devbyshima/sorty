import SwiftUI

/// One treatment for every hole in a screen.
///
/// Replaces two stock `ContentUnavailableView`s that between them covered fewer
/// situations than the app can actually reach. Typographic rather than
/// illustrated: an illustration would need a light and a dark variant and would
/// still say less than the sentence does. `EmptyState` in SortifyKit owns every
/// word.
struct EmptyStateView: View {
    let state: EmptyState
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: state.symbolName)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(state.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(state.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.spoken)

            if let actionTitle = state.actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SortifyTheme.accent)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity)
    }
}
