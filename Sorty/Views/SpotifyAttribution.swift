import SwiftUI

/// Required attribution, wherever Spotify's metadata is shown.
///
/// Spotify's Developer Policy § II.4: *"If you display any Spotify Content you
/// must clearly attribute the content as being supplied and made available by
/// Spotify, by using the Spotify Marks. […] Metadata, cover art and Audio
/// Preview Clips must be accompanied by a link back to the applicable album,
/// content or playlist on the Spotify Service."*
///
/// Every screen in Sorty that lists tracks is showing exactly that metadata,
/// so this belongs at the foot of each of them. It was dropped from both list
/// screens as collateral of the library and track-list rebuild in `b15aa47`,
/// which is the failure this doc comment exists to make expensive to repeat:
/// **if you are rewriting a screen that lists Spotify's data, it keeps this.**
///
/// Four rules from the Design & Branding Guidelines shape what is drawn, and
/// each one is doing work here rather than being quoted for completeness
/// (ADR-0013):
///
/// - **The full logo, from Spotify's own file.** *"In partner integrations, you
///   should always use our full logo (icon + wordmark)."* The asset is theirs,
///   unmodified, out of `2024-spotify-full-logo.zip`.
/// - **Monochrome, not green.** *"The Spotify green logo should only be used on
///   a black or white background, for any other background you should use a
///   monochrome logo."* `SortyTheme.background` is `#F4F4F7` light and
///   `#0D0D0D` dark - neither is black or white, so green is out and the
///   catalogue carries the black and white files as appearance variants.
/// - **Never below 70pt.** *"The Spotify logo should never be smaller than
///   70px."* Dynamic Type may grow it and may not shrink it, hence the `max`.
/// - **An exclusion zone of half the icon's height**, kept clear of competing
///   elements - which is what the padding is, not taste.
///
/// No text accompanies it, and that is also a rule rather than a preference:
/// *"Don't use the logo in a sentence or as a letter."* The wordmark says
/// Spotify; a caption saying it again would be the sentence.
///
/// Not `.template` rendering, for the same reason: *"Don't fill the lines of the
/// logo."* The two official files are the two permitted colourways.
struct SpotifyAttribution: View {
    @Environment(\.openURL) private var openURL

    /// Where the link back points. Defaults to the service; a screen that shows
    /// one playlist's contents should hand over that playlist, which is what
    /// § II.4's "the applicable […] playlist" asks for.
    var url: URL?

    /// Grows with Dynamic Type, and the bounds at both ends are deliberate.
    ///
    /// The floor is Spotify's. The **ceiling is ours**, and it is here because
    /// the uncapped version was measured: at accessibility-extra-extra-extra
    /// -large `@ScaledMetric` took 70pt to roughly 350, which made a footer mark
    /// the largest element on the library screen. A logo is not text - the
    /// legibility floor for it is the one Spotify set - so it tracks the text
    /// size a little, out of courtesy to a listener who has asked for larger,
    /// and then stops.
    @ScaledMetric(relativeTo: .caption) private var scaledWidth: Double = Self.minimumWidth

    /// The guidelines' digital floor, read as points.
    private static let minimumWidth: Double = 70

    /// 823.46 x 225.25 in the official file's viewBox. Held here so the
    /// exclusion zone can be computed from the drawn height rather than guessed.
    private static let aspect: Double = 823.46 / 225.25

    private var width: Double { min(max(Self.minimumWidth, scaledWidth), Self.minimumWidth * 2) }

    /// Half the icon's height, and the icon is as tall as the logo.
    private var exclusionZone: Double { (width / Self.aspect) / 2 }

    var body: some View {
        Button {
            openURL(url ?? URL(string: "https://open.spotify.com")!)
        } label: {
            Image("SpotifyLogo")
                .resizable()
                .scaledToFit()
                .frame(width: width)
                .padding(exclusionZone)
                // The exclusion zone alone leaves a 38pt row, and this is a
                // link. 44 is the tappable minimum.
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Spotify")
        .accessibilityHint("Opens Spotify.")
    }
}
