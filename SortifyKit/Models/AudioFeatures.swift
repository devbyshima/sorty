import Foundation

/// The per-track acoustic attributes every sortable column except popularity,
/// release date and add date is derived from.
///
/// Field names and value ranges mirror Spotify's `/v1/audio-features` payload so
/// providers that mimic that shape decode without a translation layer.
public struct AudioFeatures: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    /// Beats per minute.
    public let tempo: Double?
    /// 0…1
    public let energy: Double?
    /// 0…1
    public let danceability: Double?
    /// Decibels, typically -60…0
    public let loudness: Double?
    /// 0…1 — musical positiveness.
    public let valence: Double?
    /// 0…1
    public let acousticness: Double?
    /// 0…1
    public let instrumentalness: Double?
    /// 0…1
    public let liveness: Double?
    /// 0…1
    public let speechiness: Double?
    /// Pitch class, 0 = C … 11 = B, -1 when undetected.
    public let key: Int?
    /// 1 = major, 0 = minor.
    public let mode: Int?
    /// Estimated beats per bar.
    public let timeSignature: Int?
    public let durationMS: Int?

    enum CodingKeys: String, CodingKey {
        case id, tempo, energy, danceability, loudness, valence
        case acousticness, instrumentalness, liveness, speechiness, key, mode
        case timeSignature = "time_signature"
        case durationMS = "duration_ms"
    }

    public init(
        id: String,
        tempo: Double? = nil,
        energy: Double? = nil,
        danceability: Double? = nil,
        loudness: Double? = nil,
        valence: Double? = nil,
        acousticness: Double? = nil,
        instrumentalness: Double? = nil,
        liveness: Double? = nil,
        speechiness: Double? = nil,
        key: Int? = nil,
        mode: Int? = nil,
        timeSignature: Int? = nil,
        durationMS: Int? = nil
    ) {
        self.id = id
        self.tempo = tempo
        self.energy = energy
        self.danceability = danceability
        self.loudness = loudness
        self.valence = valence
        self.acousticness = acousticness
        self.instrumentalness = instrumentalness
        self.liveness = liveness
        self.speechiness = speechiness
        self.key = key
        self.mode = mode
        self.timeSignature = timeSignature
        self.durationMS = durationMS
    }

    public static let musicalKeyNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    /// e.g. "F♯ min". Nil when the provider didn't detect a key.
    public var keyDescription: String? {
        guard let key, key >= 0, key < Self.musicalKeyNames.count else { return nil }
        let name = Self.musicalKeyNames[key]
        guard let mode else { return name }
        return mode == 1 ? "\(name) maj" : "\(name) min"
    }
}
