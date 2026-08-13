import SwiftUI

/// One track, and every Attribute it has.
///
/// Rebuilt around the cover: large, centred, and the subject of the screen
/// rather than a stamp beside a title. The track's words sit **beneath** the
/// artwork, not on it - Spotify's design guidelines forbid overlaying text on
/// their artwork, so the "text at the bottom of the cover" this was asked for
/// is expressed as text directly under a cover that fills the width, which
/// reads the same and is permitted.
///
/// Everything on screen is decided by `TrackDetail` in SortyKit; this file
/// measures and draws.
struct TrackDetailSheet: View {
    let detail: TrackDetail

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                cover
                identity
                openInSpotify
                attributes
            }
            .padding(.bottom, 28)
        }
        .debugScrolled()
        .background(SortyTheme.background)
        // The bar owns the blur, as it does on the playlist screen.
        //
        // There is no `NavigationStack` here any more. It existed only to draw
        // a title and a close button, and it brought a bar whose background
        // could not be the blur - so the blur had to be a separate band
        // underneath it, which is what made the top of this sheet read as a
        // coloured slab instead of as artwork passing under a bar.
        //
        // The overscan is 0: a sheet has no status bar to reach up under, and
        // reaching past its own top edge draws over the presenting screen.
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenTopBar(title: "Track", overscan: 0, topPadding: 14) {
                EmptyView()
            } trailing: {
                TopBarButton(systemImage: "xmark", label: "Close") { dismiss() }
            }
        }
    }

    // MARK: - Cover

    /// Fills the width, minus a margin, and stays square.
    ///
    /// At accessibility sizes it shrinks rather than grows: the sheet's job is
    /// thirteen readings, and a cover that scales with the text would push all
    /// of them below the fold. The old layout capped a *growing* cover at 128pt
    /// for the same reason; this is that decision expressed the other way up.
    private var cover: some View {
        StickerCover(images: detail.artworkImages)
            .frame(maxWidth: isAccessibilitySize ? 180 : 300)
            .shadow(color: SortyTheme.cardShadow(colorScheme), radius: 20, y: 12)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24)
            // Longer than the blur's fade, with room to spare: a Gaussian's
            // visible smear runs past its nominal radius, so matching the fade
            // exactly still left a haze on the artwork's top edge. Tracks
            // `TopBlur.fade`, which went from 20 to 40.
            .padding(.top, 52)
            .padding(.bottom, 18)
            // The title beneath already names the track, and what `CoverImage`
            // shows while a fetched cover resolves is a shimmer that is itself
            // hidden from VoiceOver - there is nothing here to announce.
            .accessibilityHidden(true)
    }

    /// Directly under the cover, centred with it.
    private var identity: some View {
        VStack(spacing: 4) {
            Text(detail.title)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Absent for a podcast episode, which belongs to a show.
            if let album = detail.album {
                Text(album)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var openInSpotify: some View {
        if let url = detail.spotifyURL {
            Button {
                openURL(url)
            } label: {
                // Wordmark-free and glyph-free by request. Spotify's guidelines
                // list the sanctioned labels as GET SPOTIFY FREE, OPEN SPOTIFY,
                // PLAY ON SPOTIFY and LISTEN ON SPOTIFY; "Open on Spotify" sits
                // between the first two rather than on the list, which is worth
                // knowing but is the dev's call.
                //
                // Sorty's accent, not Spotify's green, and the reason is
                // arithmetic rather than identity (ADR-0013). `onAccent`
                // resolves to `systemBackground` - white in light - which on
                // `#1DB954` measured 2.59:1, under AA for this weight. That is
                // precisely the failure ADR-0006 built the token to prevent,
                // pointed at a background that ADR never measured: the token is
                // only correct against the accent it is named for. On the accent
                // it is 5.95:1 light and 6.37:1 dark, by that ADR's own table.
                Text("Open on Spotify")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SortyTheme.onAccent)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(SortyTheme.accent, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 22)
        }
    }

    // MARK: - Readings

    private var attributes: some View {
        VStack(spacing: 18) {
            ForEach(detail.sections) { section in
                VStack(alignment: .leading, spacing: 12) {
                    Text(section.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 0) {
                        ForEach(Array(section.readings.enumerated()), id: \.element.id) { index, reading in
                            readingRow(reading)

                            if index < section.readings.count - 1 {
                                Rectangle()
                                    .fill(SortyTheme.hairline)
                                    .frame(height: 1)
                                    .padding(.leading, 14)
                            }
                        }
                    }
                    .background(SortyTheme.surface, in: .rect(cornerRadius: 14))

                    if let footer = section.footer {
                        Text(footer)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    /// Name and value share a line until the text is large enough that both
    /// would truncate, which on this screen would leave a number with nothing
    /// naming it.
    private var readingLayout: AnyLayout {
        isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
    }

    private func readingRow(_ reading: TrackDetail.Reading) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            readingLayout {
                Text(reading.attribute.name)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                // A Spacer would expand the wrong way once the layout stacks.
                if !isAccessibilitySize {
                    Spacer(minLength: 8)
                }

                // Missing measurements are spelled out and drawn back: the
                // accent is what a real value looks like here, so an absent one
                // must not borrow it.
                Text(reading.displayValue)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(
                        reading.isAvailable
                            ? AnyShapeStyle(SortyTheme.accent)
                            : AnyShapeStyle(.secondary)
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Absent where the value is, and absent where every track scored
            // the same - decided in SortyKit, so the sheet and the rows can't
            // disagree about when a bar means something.
            if let fraction = reading.fraction {
                PositionBar(fraction: fraction, fillsWidth: true)
            }

            // The point of the sheet: a loudness of −7 means nothing until
            // something says the scale runs to −60.
            Text(reading.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        // One stop per Attribute rather than three. Left uncombined, six
        // identical "Unavailable" stops arrive in a row with nothing naming
        // which Attribute each belongs to.
        .accessibilityElement(children: .combine)
    }
}
