import Foundation

/// The sortable columns, in the order the reference app presents them.
public enum SortColumn: String, CaseIterable, Sendable, Identifiable, Hashable {
    case order, title, artist, release, added
    case bpm, energy, dance, loud, valence, length, acoustic, pop
    case asep, rnd

    public var id: String { rawValue }

    /// Column header text.
    public var label: String {
        switch self {
        case .order: "#"
        case .title: "Title"
        case .artist: "Artist"
        case .release: "Release"
        case .added: "Added"
        case .bpm: "BPM"
        case .energy: "Energy"
        case .dance: "Dance"
        case .loud: "Loud"
        case .valence: "Valence"
        case .length: "Length"
        case .acoustic: "Acoustic"
        case .pop: "Pop."
        case .asep: "A.Sep"
        case .rnd: "Rnd"
        }
    }

    /// Spelled-out name, used for accessibility labels and the sort picker.
    public var longLabel: String {
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
        case .asep: "Artist separation"
        case .rnd: "Random"
        }
    }

    /// Tooltip / accessibility hint.
    public var help: String {
        switch self {
        case .order: "Original track order"
        case .title: "Track title"
        case .artist: "Primary artist"
        case .release: "Release date"
        case .added: "Date added to playlist"
        case .bpm: "Tempo in BPM"
        case .energy: "Overall energy"
        case .dance: "Danceability"
        case .loud: "Loudness in dB"
        case .valence: "How positive"
        case .length: "Duration"
        case .acoustic: "Acousticness"
        case .pop: "Popularity"
        case .asep: "Artist separation"
        case .rnd: "Random shuffle"
        }
    }

    /// Numeric columns compare by value; the rest compare as localized text.
    public var isNumeric: Bool {
        switch self {
        case .title, .artist, .release, .added: false
        default: true
        }
    }

    /// Artist separation and random produce one meaningful arrangement, so the
    /// asc/desc affordance is suppressed and the saved-playlist name omits it.
    public var directionMatters: Bool {
        switch self {
        case .asep, .rnd: false
        default: true
        }
    }

    /// True when the value comes from the audio-feature provider rather than
    /// from Spotify's own track metadata. Used to explain empty columns.
    public var needsAudioFeatures: Bool {
        switch self {
        case .bpm, .energy, .dance, .loud, .valence, .acoustic: true
        default: false
        }
    }

    /// Fixed cell width in points. The table scrolls horizontally rather than
    /// compressing, so header and body cells must agree on a single number.
    public var width: Double {
        switch self {
        case .order: 40
        case .title: 168
        case .artist: 132
        case .release, .added: 96
        case .length: 64
        case .acoustic, .valence, .energy: 72
        default: 60
        }
    }

    /// What the column measures, spelled out for the FAQ.
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
        case .asep:
            "Not an attribute of the music — Sortify computes this. It rearranges the playlist so tracks by the same artist land as far apart as possible."
        case .rnd:
            "A random value per track. Tap the column again to reshuffle."
        }
    }
}

public enum SortDirection: String, Sendable, Hashable {
    case ascending, descending

    public var toggled: SortDirection { self == .ascending ? .descending : .ascending }

    /// Word used when naming a saved playlist ("increasing BPM").
    public var savedNameWord: String { self == .ascending ? "increasing" : "decreasing" }

    public var multiplier: Int { self == .ascending ? 1 : -1 }
}
