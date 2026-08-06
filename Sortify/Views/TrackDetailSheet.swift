import SwiftUI

/// One track, and every Attribute it has.
///
/// The list behind this sheet reads one Attribute down a playlist. This reads
/// every Attribute across one track — the half of the old table ADR-0001 traded
/// away, and the reason that trade was acceptable. Everything on screen is
/// decided by `TrackDetail` in SortifyKit; this file measures and draws.
struct TrackDetailSheet: View {
    let detail: TrackDetail

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Artwork grows with the text rather than sitting as a stamp beside an
    /// accessibility-sized title — but only so far. Left to scale freely it
    /// reaches about 260pt at the largest size and the sheet opens on a cover
    /// and nothing else, which on the screen that exists to show thirteen
    /// Attributes is the wrong thing to have made room for.
    @ScaledMetric(relativeTo: .headline) private var scaledArtworkSide: Double = 84
    private var artworkSide: Double { min(scaledArtworkSide, 128) }

    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    identity
                    if let url = detail.spotifyURL {
                        Button {
                            openURL(url)
                        } label: {
                            Label("Open in Spotify", systemImage: "arrow.up.forward.app")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }

                ForEach(detail.sections) { section in
                    Section {
                        ForEach(section.readings) { reading in
                            readingRow(reading)
                        }
                    } header: {
                        Text(section.title)
                    } footer: {
                        if let footer = section.footer {
                            Text(footer)
                        }
                    }
                }
            }
            .navigationTitle("Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Identity

    /// Artwork beside the words normally; above them once the text is large
    /// enough that a title sharing the line would wrap to a column two words
    /// wide.
    private var identityLayout: AnyLayout {
        isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
    }

    private var identity: some View {
        identityLayout {
            // Hidden rather than merged: the title beside it already names the
            // track, and `CoverImage` shows an unlabelled spinner while a
            // fetched cover resolves. Every other call site sits inside a view
            // that ignores its children, so this is the first place that
            // spinner could have reached VoiceOver.
            CoverImage(url: detail.artworkURL)
                .frame(width: artworkSide, height: artworkSide)
                .clipShape(.rect(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(detail.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Absent for a podcast episode, which belongs to a show.
                if let album = detail.album {
                    Text(album)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Readings

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
                // must not borrow it. Drawn back only as far as `.secondary`,
                // though — this word is the *only* thing separating "we have no
                // measurement" from a blank row, so it has to stay readable.
                Text(reading.displayValue)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(
                        reading.isAvailable
                            ? AnyShapeStyle(SortifyTheme.accent)
                            : AnyShapeStyle(.secondary)
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Absent where the value is, and absent where every track scored
            // the same — decided in SortifyKit, so the sheet and the rows can't
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
        .padding(.vertical, 2)
        // One stop per Attribute — "BPM, Unavailable, The estimated tempo…" —
        // rather than three. Left uncombined, six identical "Unavailable" stops
        // arrive in a row with nothing naming which Attribute each belongs to,
        // and thirteen Attributes cost thirty-nine swipes. Every other
        // row-shaped surface here is collapsed the same way; the bar is already
        // hidden, so it stays out of the merge.
        .accessibilityElement(children: .combine)
    }
}
