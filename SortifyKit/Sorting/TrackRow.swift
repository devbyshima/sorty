import Foundation

/// One track of a playlist, flattened together with every Attribute it has, so
/// arranging never has to reach back into the network layer.
public struct TrackRow: Sendable, Identifiable, Hashable {
    /// Stable identity — playlists may legitimately contain the same track
    /// twice, so the original index is part of the identity, not the track ID.
    public let id: Int
    /// 0-based position in the playlist as Spotify returned it.
    public let originalIndex: Int
    public let playable: Playable
    public let addedAt: String?
    public var features: AudioFeatures?
    /// Release date of the containing album, looked up separately because the
    /// simplified album inside a track omits it.
    public var albumReleaseDate: String?
    /// Position assigned by the artist-separation pass.
    public var artistSeparationIndex: Int?

    public init(
        originalIndex: Int,
        playable: Playable,
        addedAt: String? = nil,
        features: AudioFeatures? = nil,
        albumReleaseDate: String? = nil,
        artistSeparationIndex: Int? = nil
    ) {
        self.id = originalIndex
        self.originalIndex = originalIndex
        self.playable = playable
        self.addedAt = addedAt
        self.features = features
        self.albumReleaseDate = albumReleaseDate
        self.artistSeparationIndex = artistSeparationIndex
    }

    // MARK: - Attribute values

    /// Numeric value for an Attribute, or nil when unavailable. Nil always
    /// sorts last regardless of direction.
    public func numericValue(for attribute: Attribute) -> Double? {
        switch attribute {
        case .order: Double(originalIndex)
        case .bpm: features?.tempo.map { $0.rounded() }
        case .energy: features?.energy.map { ($0 * 100).rounded() }
        case .dance: features?.danceability.map { ($0 * 100).rounded() }
        case .loud: features?.loudness.map { $0.rounded() }
        case .valence: features?.valence.map { ($0 * 100).rounded() }
        case .length: (features?.durationMS ?? playable.durationMS).map(Double.init)
        case .acoustic: features?.acousticness.map { ($0 * 100).rounded() }
        case .pop: Double(playable.popularity ?? 0)
        case .title, .artist, .release, .added: nil
        }
    }

    /// Text value for the non-numeric Attributes.
    public func textValue(for attribute: Attribute) -> String? {
        switch attribute {
        case .title: playable.name
        case .artist: playable.primaryArtistName ?? ""
        case .release: albumReleaseDate
        case .added: validAddedAt(addedAt).map { String($0.prefix(10)) }
        default: nil
        }
    }

    /// What the user is shown. Empty string means "no value".
    public func displayValue(for attribute: Attribute) -> String {
        if attribute.isNumeric {
            guard let value = numericValue(for: attribute) else { return "" }
            switch attribute {
            case .order: return String(Int(value) + 1)
            case .length: return TrackRow.formatDuration(ms: Int(value))
            default: return String(Int(value))
            }
        }
        return textValue(for: attribute) ?? ""
    }

    /// Milliseconds as `m:ss`.
    public static func formatDuration(ms: Int) -> String {
        let totalSeconds = ms / 1000
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }

    /// Only real Spotify tracks and episodes can be written back. Local files
    /// have no server-side URI and are silently dropped on save, exactly as the
    /// reference app does.
    public var savableURI: String? {
        guard let uri = playable.uri else { return nil }
        guard uri.hasPrefix("spotify:track:") || uri.hasPrefix("spotify:episode:") else { return nil }
        return uri
    }
}
