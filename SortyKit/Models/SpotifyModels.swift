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
    /// Whether Spotify actually reported a count, as opposed to Sorty
    /// defaulting one.
    ///
    /// Absent is not zero. Since February 2026 a playlist's contents object is
    /// returned only for playlists the listener owns or collaborates on, and the
    /// count lives inside it, so every other listener's playlist arrives without
    /// one. The library drops playlists with nothing in them, and reading a
    /// missing count as an empty playlist is what silently removed all of them.
    public let trackCountIsKnown: Bool
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
        let reported = newStyle ?? oldStyle
        trackCountIsKnown = reported != nil
        tracks = reported ?? PlaylistTrackCount(total: 0)
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
        trackCountIsKnown: Bool = true,
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
        self.trackCountIsKnown = trackCountIsKnown
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

    /// A playlist Spotify generated, by the shape of its id.
    ///
    /// `37i9dQZ` is the stem every playlist Spotify makes has carried for a
    /// decade: `37i9dQZF1DX…` for the editorial lists, `37i9dQZF1E…` for the
    /// Daily Mixes and the radio ones, `37i9dQZEVXc…` for the ones built for you
    /// (Discover Weekly, Release Radar, On Repeat) and `37i9dQZEVXb…` for the
    /// charts. It is folklore: Spotify documents none of it and could stop
    /// tomorrow.
    ///
    /// Which is exactly why nothing that decides whether a request is worth
    /// making rests on it any more. It decides two things, and both are safe to
    /// be wrong about: whether Overwrite is offered, and which sentence a
    /// refusal gets.
    ///
    /// **It read `37i9dQZF` until August 2026, which does not match Discover
    /// Weekly** - whose id begins `37i9dQZEVXc`. The one playlist the predicate
    /// was named after had never once satisfied it, and it survived because
    /// every fixture in this repository used Today's Top Hits' id with Discover
    /// Weekly's name on it. See ADR-0018.
    public var isSpotifyGenerated: Bool { id.hasPrefix("37i9dQZ") }

    /// Whether Spotify itself published this, under any of the accounts it
    /// publishes under.
    ///
    /// `spotify` is the one everyone knows. The charts and the regional
    /// editorial desks use their own - `spotifycharts`, `spotifyusa`,
    /// `spotify_uk_`, and a long tail of the same shape - and a playlist of
    /// theirs used to fall through to `.other`, where the copy told the listener
    /// to ask whoever owns it to make it collaborative. Nobody is going to ask
    /// Spotify to make RapCaviar collaborative.
    ///
    /// A prefix rather than a published list, because there is no published list
    /// and a new regional account would silently rejoin `.other`. The cost is
    /// that a listener whose own account id begins "spotify" is filed under the
    /// Spotify chip and given Spotify's sentence instead of their name; nothing
    /// they can open stops opening, because what opens is decided by ownership
    /// alone, which is a fact rather than a guess.
    public var isSpotifyOwned: Bool { isSpotifyGenerated || owner.id.hasPrefix("spotify") }

    public func category(currentUserID: String?) -> PlaylistCategory {
        if isSpotifyOwned { return .spotify }
        if let currentUserID, owner.id == currentUserID { return .mine }
        return .other
    }

    /// True only where Spotify said outright that this playlist holds nothing.
    ///
    /// The library shows nothing it cannot arrange, and an empty playlist has
    /// nothing to arrange. A playlist whose count never arrived is a different
    /// thing entirely and stays: see `trackCountIsKnown`.
    public var isReportedEmpty: Bool { trackCountIsKnown && tracks.total == 0 }

    /// Whether Spotify will hand over this playlist's contents at all.
    ///
    /// Get Playlist Items is "only accessible for playlists owned by the current
    /// user or playlists the user is a collaborator of", and answers 403 for
    /// anything else. That rule arrived with the February 2026 Development Mode
    /// migration and it binds every Sorty listener, because every one of them
    /// is a Development Mode app by construction: a single app is capped at five
    /// listeners, which is why each brings a Client ID of their own.
    ///
    /// So this is not the same question as `isWritable(byUserID:)`. A playlist
    /// can fail this one and never open at all, which is worth knowing before
    /// the tap rather than after a spinner.
    ///
    /// Not knowing is not a refusal: with no `userID` yet, or a playlist whose
    /// owner Spotify omitted, the request is still worth making.
    ///
    /// **The documented rule and nothing else.** It also refused anything whose
    /// id carried Spotify's stem or whose owner was the `spotify` account, until
    /// August 2026. Both were redundant - Spotify is not you, so ownership
    /// already refuses them - and the first was wrong for the one kind of Client
    /// ID old enough to read them, which is exactly the grandfathered ID
    /// `FeatureSourceMode.spotify` exists for. Refusing on Spotify's behalf,
    /// using folklore, in the one case where Spotify might say yes, is the shape
    /// of pre-check ADR-0008 warned about and ADR-0018 removes.
    public func contentsAreReadable(byUserID userID: String?) -> Bool {
        if collaborative { return true }
        guard let userID, !owner.id.isEmpty else { return true }
        return owner.id == userID
    }

    /// Overwriting requires being the owner, and never works for a playlist
    /// Spotify generated even though it reports you as owner of some of them.
    public func isWritable(byUserID userID: String?) -> Bool {
        guard let userID else { return false }
        guard owner.id == userID else { return false }
        return !isSpotifyGenerated
    }

    /// Every size this playlist's cover comes in, for a view that knows how big
    /// it is drawing.
    public var artworkImages: [SpotifyImage] { images ?? [] }

    /// Picks the smallest image that is still sharp at card size on retina.
    ///
    /// Sized for a card. The playlist screen draws its cover far larger and
    /// resolves from `artworkImages` instead.
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

extension Array where Element == SpotifyImage {

    /// The smallest cover that is still sharp at `pixels`, or the largest there
    /// is when nothing reaches it.
    ///
    /// Spotify offers each cover at 640, 300 and 64. The old accessors asked
    /// for a fixed floor - 160 for a track, 300 for a playlist card - which was
    /// right when every cover on screen was a 44pt thumbnail and wrong the
    /// moment one became the subject of a screen: a 300pt cover on a 3x display
    /// needs 900 pixels and was being handed 300, which is visibly soft. Asking
    /// for the size actually being drawn is the only version of this that stays
    /// correct as layouts change.
    ///
    /// Still the *smallest* that suffices, not simply the largest: a 44pt row
    /// thumbnail has no use for 640 pixels, and a scrolling list of them would
    /// pay for every one.
    public func url(coveringPixels pixels: Int) -> URL? {
        guard !isEmpty else { return nil }

        let sized = filter { $0.width != nil }.sorted { ($0.width ?? 0) < ($1.width ?? 0) }
        guard !sized.isEmpty else { return URL(string: self[0].url) }

        let match = sized.first { ($0.width ?? 0) >= pixels } ?? sized[sized.count - 1]
        return URL(string: match.url)
    }

    /// The widest cover on offer, in points at this display scale.
    ///
    /// A view drawing a cover larger than this is upscaling, and no choice of
    /// file will fix it: there is no bigger one. Worth asking before committing
    /// to a size.
    public func maximumPointWidth(scale: CGFloat) -> CGFloat? {
        let widest = compactMap(\.width).max()
        guard let widest, scale > 0 else { return nil }
        return CGFloat(widest) / scale
    }
}

public enum PlaylistCategory: String, Sendable, CaseIterable, Hashable {
    /// `.personalized` went in August 2026.
    ///
    /// It existed to pick between two `LoadFailure` sentences - "Spotify makes
    /// this for you" against "Spotify edits this" - and it picked with an
    /// undocumented id prefix that did not match Discover Weekly. Widening the
    /// prefix fixes Discover Weekly and breaks Top 50 Global, which would then
    /// be told Spotify makes it personally. A distinction the app cannot draw
    /// reliably is one it should stop pretending to draw, so there is one
    /// Spotify case now and one sentence naming both kinds. ADR-0018.
    case mine, spotify, other

    public var label: String {
        switch self {
        case .mine: "Mine"
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
    /// The date the album was first released, at year, month or day precision.
    ///
    /// Present on the simplified album inside a track, not only on a full album
    /// object: `release_date` is a required field of Spotify's album base object,
    /// and both the simplified and the full album derive from it. So a playlist's
    /// own response already carries every release date it has, and nothing has to
    /// be fetched to read one. This is not what the app assumed - see
    /// `TrackRow.albumReleaseDate`.
    public let releaseDate: String?

    enum CodingKeys: String, CodingKey {
        case id, name, images
        case releaseDate = "release_date"
    }

    /// The release date, or nil when the field arrived empty.
    ///
    /// Same guard as `validAddedAt`, for the same reason: a local file's album
    /// can come back with `""`, which is "no date" wearing the shape of one.
    /// Release date sorts as text, so an empty string would rank ahead of every
    /// real date rather than falling to the unrankable group.
    public var validReleaseDate: String? {
        guard let releaseDate, !releaseDate.isEmpty else { return nil }
        return releaseDate
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

/// A track *or* a podcast episode - playlists can hold both.
public struct Playable: Codable, Sendable, Hashable {
    public let id: String?
    public let name: String
    public let uri: String?
    public let durationMS: Int?
    public let artists: [TrackArtist]?
    public let album: TrackAlbum?
    /// Episodes carry their own artwork - they belong to a show, not an album,
    /// so there is no album to read it from. Tracks leave this nil and resolve
    /// through `album`.
    public let images: [SpotifyImage]?
    public let type: PlayableKind?

    enum CodingKeys: String, CodingKey {
        case id, name, uri, artists, album, images, type
        case durationMS = "duration_ms"
    }

    public init(
        id: String?,
        name: String,
        uri: String? = nil,
        durationMS: Int? = nil,
        artists: [TrackArtist]? = nil,
        album: TrackAlbum? = nil,
        images: [SpotifyImage]? = nil,
        type: PlayableKind? = .track
    ) {
        self.id = id
        self.name = name
        self.uri = uri
        self.durationMS = durationMS
        self.artists = artists
        self.album = album
        self.images = images
        self.type = type
    }

    public var isEpisode: Bool { type == .episode }
    public var primaryArtistName: String? { artists?.first?.name }

    /// Every size of this track's cover, its own if it has any and its album's
    /// otherwise. The view picks the one it needs once it knows how big it is
    /// drawing.
    public var coverImages: [SpotifyImage] { images ?? album?.images ?? [] }

    /// Cover artwork for this track or episode: its own if it has any, else its
    /// album's. One accessor so a row never has to know which kind it is
    /// holding.
    ///
    /// Sized for a row thumbnail. Anything drawing a cover larger than that
    /// should resolve from `coverImages` at the size it is actually drawing.
    public var coverImageURL: URL? {
        let candidates = images ?? album?.images
        guard let candidates, !candidates.isEmpty else { return nil }
        let sized = candidates
            .filter { $0.width != nil }
            .sorted { ($0.width ?? 0) < ($1.width ?? 0) }
        let match = sized.first { ($0.width ?? 0) >= 160 }
        return URL(string: (match ?? candidates[0]).url)
    }
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
    /// Whether the response carried an `items` array at all.
    ///
    /// A page of nothing and a page that withheld its contents decode to the
    /// same empty array, and they mean opposite things: one is a playlist with
    /// no tracks, the other is Spotify declining to send the tracks there are.
    /// February 2026 made the second shape real, so it needs a name.
    public let carriedItems: Bool

    enum CodingKeys: String, CodingKey { case items, next, total }

    public init(items: [Item], next: String? = nil, total: Int? = nil) {
        self.items = items
        self.next = next
        self.total = total
        self.carriedItems = true
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = try container.decodeIfPresent([Item].self, forKey: .items)
        items = decoded ?? []
        carriedItems = decoded != nil
        next = try container.decodeIfPresent(String.self, forKey: .next)
        total = try container.decodeIfPresent(Int.self, forKey: .total)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
        try container.encodeIfPresent(next, forKey: .next)
        try container.encodeIfPresent(total, forKey: .total)
    }
}
