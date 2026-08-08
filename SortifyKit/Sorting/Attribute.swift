import Foundation

/// A property a track has - thirteen of them, closed.
///
/// An Attribute is something a track *is*; an `Arrangement` is something you do
/// to a playlist. Nothing here knows about ordering, direction or table
/// columns: artist separation and shuffle are not Attributes, because no track
/// carries either value.
///
/// Ten are measurements of the music. The other three - position, title and
/// artist - are things a track carries rather than things it measures, but they
/// are read from the track exactly like the rest, so they belong here and not
/// among the orderings that compute their own values.
public enum Attribute: String, CaseIterable, Sendable, Identifiable, Hashable {
    case order, title, artist, release, added
    case bpm, energy, dance, loud, valence, length, acoustic, pop

    public var id: String { rawValue }

    /// Spelled out. Read by the FAQ, accessibility labels and - through
    /// `Arrangement.name` - the saved-playlist name.
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

    /// Whether this Attribute has a magnitude - somewhere a value can sit on a
    /// line, which is what a position bar draws.
    ///
    /// Not the same question as `isNumeric`, which is about how two values
    /// *compare*. A date compares as text but is genuinely earlier or later, so
    /// it has a range; a title compares as text and has none, because
    /// alphabetical order is a sequence rather than a scale and "how far
    /// through the alphabet" measures nothing.
    public var isPlottable: Bool {
        switch self {
        case .title, .artist: false
        default: true
        }
    }

    /// True when the value comes from the audio-feature provider rather than
    /// from Spotify's own track metadata - so it can legitimately be missing.
    public var isAudioFeature: Bool {
        switch self {
        case .bpm, .energy, .dance, .loud, .valence, .acoustic: true
        default: false
        }
    }

    /// THE source of explanation copy. The FAQ reads this today; the picker
    /// sheet and the track detail sheet read the same property rather than
    /// owning a second copy of the words.
    ///
    /// One sentence has to work in two places: beside a *choice* in the picker,
    /// where the question is "what does arranging by this do", and beside a
    /// *value* in the detail sheet, where it is "what am I looking at". So each
    /// says what the Attribute is first, and only then what ordering by it
    /// gets you - a sentence that opens with "in alphabetical order" explains
    /// nothing at all when it is sitting under one track's title.
    public var explanation: String {
        switch self {
        case .order:
            "The track's position in the playlist as Spotify returned it. Arrange by this to get back to where you started."
        case .title:
            "The track title. Arrange by this to put the playlist in alphabetical order."
        case .artist:
            "The first credited artist. Arrange by this to gather each artist's tracks together, alphabetically."
        case .release:
            "The release date of the album the track appears on."
        case .added:
            "The date the track was added to the playlist."
        case .bpm:
            "The estimated tempo in beats per minute. A waltz sits around 80, a pop song around 120, drum & bass around 170."
        case .energy:
            "A 0–100 measure of intensity and activity. Energetic tracks feel fast, loud and noisy, like death metal. A Bach prelude scores low."
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
