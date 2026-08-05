import Foundation

/// A property a track has — thirteen of them, closed.
///
/// An Attribute is something a track *is*; an `Arrangement` is something you do
/// to a playlist. Nothing here knows about ordering, direction or table
/// columns: artist separation and shuffle are not Attributes, because no track
/// carries either value.
///
/// Ten are measurements of the music. The other three — position, title and
/// artist — are things a track carries rather than things it measures, but they
/// are read from the track exactly like the rest, so they belong here and not
/// among the orderings that compute their own values.
public enum Attribute: String, CaseIterable, Sendable, Identifiable, Hashable {
    case order, title, artist, release, added
    case bpm, energy, dance, loud, valence, length, acoustic, pop

    public var id: String { rawValue }

    /// Spelled out. Read by the FAQ, accessibility labels and — through
    /// `Arrangement.name` — the saved-playlist name.
    public var name: String {
        switch self {
        case .order: "Original order"
        case .title: "Title"
        case .artist: "Artist"
        case .release: "Release date"
        case .added: "Date added"
        case .bpm: "BPM"
        case .energy: "Energy"
        case .dance: "Danceability"
        case .loud: "Loudness"
        case .valence: "Valence"
        case .length: "Length"
        case .acoustic: "Acousticness"
        case .pop: "Popularity"
        }
    }

    /// Numeric attributes compare by value; the rest compare as localized text.
    public var isNumeric: Bool {
        switch self {
        case .title, .artist, .release, .added: false
        default: true
        }
    }

    /// True when the value comes from the audio-feature provider rather than
    /// from Spotify's own track metadata — so it can legitimately be missing.
    public var isAudioFeature: Bool {
        switch self {
        case .bpm, .energy, .dance, .loud, .valence, .acoustic: true
        default: false
        }
    }

    /// THE source of explanation copy. The FAQ reads this today; the picker
    /// sheet and the track detail sheet read the same property rather than
    /// owning a second copy of the words.
    public var explanation: String {
        switch self {
        case .order:
            "The track's position in the playlist as Spotify returned it. Sort by this to get back to where you started."
        case .title:
            "The track title, sorted alphabetically."
        case .artist:
            "The first credited artist, sorted alphabetically."
        case .release:
            "The release date of the album the track appears on."
        case .added:
            "The date the track was added to the playlist."
        case .bpm:
            "The estimated tempo in beats per minute. A waltz sits around 80, a pop song around 120, drum & bass around 170."
        case .energy:
            "A 0–100 measure of intensity and activity. Energetic tracks feel fast, loud and noisy — think death metal. A Bach prelude scores low."
        case .dance:
            "A 0–100 score for how suitable a track is for dancing, from tempo, rhythm stability, beat strength and regularity."
        case .loud:
            "Overall loudness in decibels, averaged across the track. Typically −60 to 0 dB."
        case .valence:
            "A 0–100 measure of musical positiveness. High valence sounds happy or euphoric; low valence sounds sad or angry."
        case .length:
            "The duration of the track."
        case .acoustic:
            "A 0–100 confidence score that the track is acoustic. 100 means high confidence."
        case .pop:
            "A 0–100 score Spotify assigns from recent play counts. It changes often."
        }
    }
}
