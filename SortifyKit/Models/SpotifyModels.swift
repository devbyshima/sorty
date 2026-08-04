import Foundation

// MARK: - User

public struct SpotifyUser: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let displayName: String?
    public let images: [SpotifyImage]?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case images
    }

    public init(id: String, displayName: String? = nil, images: [SpotifyImage]? = nil) {
        self.id = id
        self.displayName = displayName
        self.images = images
    }
}

// MARK: - Image

public struct SpotifyImage: Codable, Sendable, Hashable {
    public let url: String
    public let width: Int?
    public let height: Int?

    public init(url: String, width: Int? = nil, height: Int? = nil) {
        self.url = url
        self.width = width
        self.height = height
    }
}

// MARK: - Playlist

public struct PlaylistOwner: Codable, Sendable, Hashable {
    public let id: String
    public let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }

    public init(id: String, displayName: String? = nil) {
        self.id = id
        self.displayName = displayName
    }
}

public struct PlaylistTrackCount: Codable, Sendable, Hashable {
    public let total: Int
    public init(total: Int) { self.total = total }
}

public struct Playlist: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let uri: String
    public let owner: PlaylistOwner
    public let images: [SpotifyImage]?
    public let tracks: PlaylistTrackCount
    public let collaborative: Bool
    /// Spotify returns `null` here when the caller can't determine visibility.
    public let isPublic: Bool?
    public let rawDescription: String?

    enum CodingKeys: String, CodingKey {
        case id, name, uri, owner, images, tracks, collaborative
        case items
        case isPublic = "public"
        case rawDescription = "description"
    }

    /// The February 2026 API renamed the playlist's `tracks` object to `items`
    /// and marked `tracks` deprecated. Both spellings are still in flight
    /// depending on how old the caller's Client ID is, so accept either.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Untitled"
        uri = try container.decodeIfPresent(String.self, forKey: .uri) ?? "spotify:playlist:\(id)"
        owner = try container.decodeIfPresent(PlaylistOwner.self, forKey: .owner) ?? PlaylistOwner(id: "")
        images = try container.decodeIfPresent([SpotifyImage].self, forKey: .images)
        collaborative = try container.decodeIfPresent(Bool.self, forKey: .collaborative) ?? false
        isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic)
        rawDescription = try container.decodeIfPresent(String.self, forKey: .rawDescription)

        let newStyle = try container.decodeIfPresent(PlaylistTrackCount.self, forKey: .items)
        let oldStyle = try container.decodeIfPresent(PlaylistTrackCount.self, forKey: .tracks)
        tracks = newStyle ?? oldStyle ?? PlaylistTrackCount(total: 0)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(uri, forKey: .uri)
        try container.encode(owner, forKey: .owner)
        try container.encodeIfPresent(images, forKey: .images)
        try container.encode(tracks, forKey: .tracks)
        try container.encode(collaborative, forKey: .collaborative)
        try container.encodeIfPresent(isPublic, forKey: .isPublic)
        try container.encodeIfPresent(rawDescription, forKey: .rawDescription)
    }

    public init(
        id: String,
        name: String,
        uri: String,
        owner: PlaylistOwner,
        images: [SpotifyImage]? = nil,
        tracks: PlaylistTrackCount,
        collaborative: Bool = false,
        isPublic: Bool? = nil,
        rawDescription: String? = nil
    ) {
        self.id = id
        self.name = name
        self.uri = uri
        self.owner = owner
        self.images = images
        self.tracks = tracks
        self.collaborative = collaborative
        self.isPublic = isPublic
        self.rawDescription = rawDescription
    }

    /// Spotify has been known to send the literal string "null" here.
    public var cleanDescription: String? {
        guard let raw = rawDescription else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "null" else { return nil }
        return trimmed
    }

    /// Algorithmic Spotify playlists (Discover Weekly, Daily Mix, Release Radar)
    /// all live under this prefix and can never be written to.
    public var isPersonalized: Bool { id.hasPrefix("37i9dQZF") }

    public func category(currentUserID: String?) -> PlaylistCategory {
        if isPersonalized { return .personalized }
        if owner.id == "spotify" { return .spotify }
        if let currentUserID, owner.id == currentUserID { return .mine }
        return .other
    }

    /// Overwriting requires being the owner, and never works for personalized
    /// playlists even though Spotify reports you as owner of some of them.
    public func isWritable(byUserID userID: String?) -> Bool {
        guard let userID else { return false }
        guard owner.id == userID else { return false }
        return !isPersonalized
    }

    /// Picks the smallest image that is still sharp at card size on retina.
    public var cardImageURL: URL? {
        guard let images, !images.isEmpty else { return nil }
        if images.count == 1 { return URL(string: images[0].url) }
        let minSize = 300
        let sized = images
            .filter { $0.width != nil && $0.height != nil }
            .sorted { ($0.width ?? 0) < ($1.width ?? 0) }
        let match = sized.first { ($0.width ?? 0) >= minSize && ($0.height ?? 0) >= minSize }
        return URL(string: (match ?? images[0]).url)
    }
}

public enum PlaylistCategory: String, Sendable, CaseIterable, Hashable {
    case mine, personalized, spotify, other

    public var label: String {
        switch self {
        case .mine: "Mine"
        case .personalized: "Personalized"
        case .spotify: "Spotify"
        case .other: "Other"
        }
    }
}

// MARK: - Track

public struct TrackArtist: Codable, Sendable, Hashable {
    public let id: String?
    public let name: String
    public init(id: String? = nil, name: String) {
        self.id = id
        self.name = name
    }
}

public struct TrackAlbum: Codable, Sendable, Hashable {
    public let id: String?
    public let name: String?
    public let images: [SpotifyImage]?
    /// Present on full album objects; absent on the simplified album inside a track.
    public let releaseDate: String?

    enum CodingKeys: String, CodingKey {
        case id, name, images
        case releaseDate = "release_date"
    }

    public init(id: String? = nil, name: String? = nil, images: [SpotifyImage]? = nil, releaseDate: String? = nil) {
        self.id = id
        self.name = name
        self.images = images
        self.releaseDate = releaseDate
    }
}

public enum PlayableKind: String, Codable, Sendable {
    case track, episode
}

/// A track *or* a podcast episode — playlists can hold both.
public struct Playable: Codable, Sendable, Hashable {
    public let id: String?
    public let name: String
    public let uri: String?
    public let durationMS: Int?
    public let popularity: Int?
    public let artists: [TrackArtist]?
    public let album: TrackAlbum?
    public let type: PlayableKind?

    enum CodingKeys: String, CodingKey {
        case id, name, uri, popularity, artists, album, type
        case durationMS = "duration_ms"
    }

    public init(
        id: String?,
        name: String,
        uri: String? = nil,
        durationMS: Int? = nil,
        popularity: Int? = nil,
        artists: [TrackArtist]? = nil,
        album: TrackAlbum? = nil,
        type: PlayableKind? = .track
    ) {
        self.id = id
        self.name = name
        self.uri = uri
        self.durationMS = durationMS
        self.popularity = popularity
        self.artists = artists
        self.album = album
        self.type = type
    }

    public var isEpisode: Bool { type == .episode }
    public var primaryArtistName: String? { artists?.first?.name }
}

public struct PlaylistItem: Codable, Sendable, Hashable {
    public let addedAt: String?
    public let isLocal: Bool?
    public let track: Playable?

    enum CodingKeys: String, CodingKey {
        case addedAt = "added_at"
        case isLocal = "is_local"
        case track
        case item
    }

    /// `/playlists/{id}/items` calls the payload `item`; the deprecated
    /// `/tracks` spelling calls it `track`. Decode whichever arrived.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        addedAt = try container.decodeIfPresent(String.self, forKey: .addedAt)
        isLocal = try container.decodeIfPresent(Bool.self, forKey: .isLocal)
        let newStyle = try container.decodeIfPresent(Playable.self, forKey: .item)
        let oldStyle = try container.decodeIfPresent(Playable.self, forKey: .track)
        track = newStyle ?? oldStyle
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(addedAt, forKey: .addedAt)
        try container.encodeIfPresent(isLocal, forKey: .isLocal)
        try container.encodeIfPresent(track, forKey: .track)
    }

    public init(addedAt: String? = nil, isLocal: Bool? = false, track: Playable?) {
        self.addedAt = addedAt
        self.isLocal = isLocal
        self.track = track
    }
}

/// Spotify hands back `1970-01-01T00:00:00Z` for tracks whose add date it never
/// recorded. Treat that as "unknown" rather than as the Unix epoch.
public func validAddedAt(_ raw: String?) -> String? {
    guard let raw, !raw.isEmpty, !raw.hasPrefix("1970") else { return nil }
    return raw
}

// MARK: - Paging

public struct Page<Item: Codable & Sendable>: Codable, Sendable {
    public let items: [Item]
    public let next: String?
    public let total: Int?

    public init(items: [Item], next: String? = nil, total: Int? = nil) {
        self.items = items
        self.next = next
        self.total = total
    }
}
