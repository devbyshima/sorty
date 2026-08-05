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
        // Nil, not zero. An episode has no popularity at all, and coercing that
        // to 0 made it sort as the least popular track and — once bars arrived
        // — draw one, which is exactly the "an absent measurement looking like
        // a low one" that the bars exist to avoid.
        case .pop: playable.popularity.map(Double.init)
        case .title, .artist, .release, .added: nil
        }
    }

    /// Text value for the non-numeric Attributes.
    public func textValue(for attribute: Attribute) -> String? {
        switch attribute {
        case .title: playable.name
        // Nil rather than "": a podcast episode has no artist, and an empty
        // string would sort it to the front of the alphabet as though it did.
        case .artist: playable.primaryArtistName
        case .release: albumReleaseDate
        case .added: validAddedAt(addedAt).map { String($0.prefix(10)) }
        default: nil
        }
    }

    /// Whether an Arrangement by this Attribute can place the track at all.
    /// False is what puts a track in the unrankable group rather than at the
    /// silent bottom of the list.
    public func canBeRanked(by attribute: Attribute) -> Bool {
        attribute.isNumeric
            ? numericValue(for: attribute) != nil
            : textValue(for: attribute) != nil
    }

    /// Where a value sits on a line, for the position bar.
    ///
    /// Numeric Attributes use their own value. Dates become a day count so that
    /// "released halfway through this playlist's span" is expressible — they
    /// sort as text but they are still earlier and later. Title and artist have
    /// no magnitude and return nil.
    public func plottableValue(for attribute: Attribute) -> Double? {
        guard attribute.isPlottable else { return nil }
        if attribute.isNumeric { return numericValue(for: attribute) }
        return textValue(for: attribute).flatMap(TrackRow.dayCount(fromISODate:))
    }

    /// Days since 1970 for an ISO-8601 date. Spotify's release dates come at
    /// year, month or day precision, so a partial date is padded to its first
    /// day rather than discarded.
    static func dayCount(fromISODate date: String) -> Double? {
        let parts = date.prefix(10).split(separator: "-", omittingEmptySubsequences: false)
        guard let year = Int(parts.first ?? ""), year > 0 else { return nil }
        let month = parts.count > 1 ? Int(parts[1]) ?? 1 : 1
        let day = parts.count > 2 ? Int(parts[2]) ?? 1 : 1

        var components = DateComponents()
        components.year = year
        components.month = min(max(month, 1), 12)
        components.day = min(max(day, 1), 31)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        guard let resolved = calendar.date(from: components) else { return nil }
        return resolved.timeIntervalSince1970 / 86_400
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
