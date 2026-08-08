import Foundation

/// One track in full: every Attribute it has, each placed against the same
/// playlist the rows are placed against.
///
/// This is where ADR-0001's accepted cost is repaid. The fifteen-column table
/// could be read two ways - one Attribute down the list, which the arrangement
/// list now does better, and every Attribute across one track, which a row
/// showing a single value cannot do at all. The second reading lives here, and
/// nowhere else; if it were weak the trade-off would quietly be a regression.
///
/// Assembled whole in SortifyKit and handed to the view. Which Attributes
/// appear, how they group, what an absent one says, and where each value sits
/// are all decisions worth asserting, and not one of them is layout.
public struct TrackDetail: Equatable, Sendable {

    /// What a track with no value for an Attribute reads as. A word, never a
    /// zero: every audio feature can legitimately be absent, and a `0` in that
    /// slot is a measurement the listener has no way to tell from a real one.
    public static let unavailable = "Unavailable"

    /// One Attribute, as this track has it.
    public struct Reading: Identifiable, Equatable, Sendable {
        public let attribute: Attribute
        /// Nil when the track has no value - the state `displayValue` renders
        /// as `unavailable`.
        public let value: String?
        /// Where the value sits within this playlist's span for the Attribute,
        /// or nil when there is no bar to draw. Same rule as the rows, so a bar
        /// means one thing in both places.
        public let fraction: Double?

        public var id: String { attribute.rawValue }
        public var isAvailable: Bool { value != nil }

        /// What the sheet prints, present or not.
        public var displayValue: String { value ?? TrackDetail.unavailable }

        /// Forwards to THE source of explanation copy - the same property the
        /// picker sheet and the FAQ read, never a second wording of it.
        public var explanation: String { attribute.explanation }
    }

    /// Attributes gathered by where their values come from.
    ///
    /// The split is the one `CONTEXT.md` draws, and it is the sheet's answer to
    /// the question a screen full of "Unavailable" provokes. Audio features
    /// come from a source outside Spotify and can be missing; Spotify's own
    /// metadata cannot. Grouped, the absences have a heading that explains
    /// them; interleaved, they would look like six unrelated failures.
    public struct Section: Identifiable, Equatable, Sendable {
        public let title: String
        /// Nil where the heading says enough on its own.
        public let footer: String?
        public let readings: [Reading]

        public var id: String { title }
    }

    public let title: String
    /// Artist, or what the entry is when there isn't one - the same words the
    /// row uses, so opening a track never renames it.
    public let subtitle: String
    /// Nil for a podcast episode, which belongs to a show rather than an album.
    public let album: String?
    public let artworkURL: URL?
    /// Every size the cover comes in, so a view drawing it large can fetch a
    /// file that is actually sharp at that size rather than a thumbnail.
    public let artworkImages: [SpotifyImage]
    /// The way out to Spotify, or nil for anything with no server-side URI.
    public let spotifyURL: URL?
    public let sections: [Section]

    /// Every Attribute, flattened. The sections are the display order; this is
    /// for asking whether one is present at all.
    public var readings: [Reading] { sections.flatMap(\.readings) }

    public func reading(for attribute: Attribute) -> Reading? {
        readings.first { $0.attribute == attribute }
    }

    /// `rows` is the whole loaded playlist, deliberately - not what the filter
    /// left and not what the Arrangement ranked. A bar answers "where does this
    /// sit among the others", and letting the filter move the range would make
    /// the same track draw a different length depending on what else happened
    /// to be on screen. `TrackListModel.positionRange` resolves the row bars the
    /// same way for the same reason.
    public init(row: TrackRow, in rows: [TrackRow]) {
        title = row.playable.name
        subtitle = TrackRowText.subtitle(for: row)
        album = row.playable.album?.name
        artworkURL = row.playable.coverImageURL
        artworkImages = row.playable.coverImages
        spotifyURL = row.spotifyURL

        func readings(for attributes: [Attribute]) -> [Reading] {
            attributes.map { attribute in
                let text = row.displayValue(for: attribute)
                return Reading(
                    attribute: attribute,
                    value: text.isEmpty ? nil : text,
                    fraction: AttributeRange(attribute: attribute, rows: rows)?.fraction(for: row)
                )
            }
        }

        // Partitioned out of `Attribute.allCases` rather than listed by hand,
        // so an Attribute added later appears in the sheet by existing rather
        // than by someone remembering to put it here.
        sections = [
            Section(
                title: "Audio features",
                // Deliberately does not promise that the section below never
                // goes missing. It does: a podcast episode has no artist, no
                // popularity and no album to carry a release date, and a local
                // file's album can arrive with an empty one. The honest claim is
                // about where these six come from and why they are the ones most
                // often gone, not about the others.
                footer: "Measured by a source outside Spotify rather than by Spotify itself, so these are the values most often missing for a track.",
                readings: readings(for: Attribute.allCases.filter(\.isAudioFeature))
            ),
            Section(
                title: "From Spotify",
                footer: nil,
                readings: readings(for: Attribute.allCases.filter { !$0.isAudioFeature })
            ),
        ]
    }
}
