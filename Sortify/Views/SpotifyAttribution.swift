import SwiftUI

/// Required attribution, wherever Spotify's metadata is shown.
///
/// Spotify's developer brand guidelines, checked 2026-08-06: *"If you use any
/// Spotify metadata (including artist, album and track names, album artwork,
/// and audio playback) it must always be accompanied by the Spotify brand"* and
/// *"it must always link back to the Spotify Service."*
///
/// Every screen in Sortify that lists tracks is showing exactly that metadata,
/// so this belongs at the foot of each of them rather than only in the FAQ.
///
/// The second of the two places Spotify's green is correct — the other is the
/// connect affordance. The accent is Sortify's everywhere else (ADR-0006).
///
/// > Important: the guidelines ask for the **logo** (icon + wordmark), not a
/// > wordmark set in type. Dropping the official asset into
/// > `Resources/Assets.xcassets` and swapping it in here is the outstanding
/// > step; it is a trademark file that has to be taken from Spotify's own brand
/// > resources rather than redrawn.
struct SpotifyAttribution: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            // The link back the guidelines require.
            if let url = URL(string: "https://open.spotify.com") {
                openURL(url)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "waveform.circle.fill")
                    .foregroundStyle(SortifyTheme.spotifyGreen)
                Text("Content from Spotify")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Content from Spotify")
        .accessibilityHint("Opens Spotify.")
    }
}
