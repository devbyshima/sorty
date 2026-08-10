import SwiftUI

/// One treatment for every hole in a screen.
///
/// Replaces two stock `ContentUnavailableView`s that between them covered fewer
/// situations than the app can actually reach. Typographic rather than
/// illustrated: an illustration would need a light and a dark variant and would
/// still say less than the sentence does. `EmptyState` in SortyKit owns every
/// word.
struct EmptyStateView: View {
    let state: EmptyState
    var action: (() -> Void)?
    /// Set where the way out *is Spotify*, which is currently the one state
    /// Spotify's own rule creates: a playlist it names and will not open.
    ///
    /// It replaces the text button with Spotify's mark rather than adding one.
    /// The screen behind this still shows the playlist's name and cover - which
    /// is their metadata - so the Developer Policy's attribution and its "link
    /// back to the applicable playlist" are owed here exactly as they are at the
    /// foot of a list, and were missing on this branch. One element answers
    /// both, and it is the same mark drawn the same way everywhere else in the
    /// app, so a listener meets one Spotify affordance rather than two.
    var spotifyURL: URL?

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

            if let spotifyURL {
                // No caption under it, which is Spotify's rule rather than a
                // layout choice: the wordmark says Spotify, and a line saying it
                // again would be the logo used in a sentence. The paragraph
                // above already names what tapping it is for.
                SpotifyAttribution(url: spotifyURL)
                    .padding(.top, 2)
            } else if let actionTitle = state.actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SortyTheme.accent)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity)
    }
}
