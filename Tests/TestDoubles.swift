import Foundation

// The collaborators every model test drives the real model against. The spec's
// Testing Decisions name these as the seam, so they live in one place rather
// than being re-declared per suite.

/// Records what was written back, so save behaviour can be asserted without a
/// network or a Spotify account.
actor RecordingMusicService: MusicService {
    nonisolated let canWriteBack: Bool

    private(set) var createdPlaylists: [(name: String, isPublic: Bool, description: String)] = []
    private(set) var writes: [(playlistID: String, uris: [String])] = []
    /// Every album lookup, including the empty ones - so "it never asked" can be
    /// told apart from "it asked for nothing".
    private(set) var albumRequests: [[String]] = []
    /// Every playlist whose contents were asked for, so "it never asked" can be
    /// asserted - which is the whole of what a refusal known in advance does.
    private(set) var itemRequests: [String] = []

    private let items: [PlaylistItem]
    private let failWrites: Bool
    private let albumsHaveDates: Bool
    private let albumsRefused: Bool

    init(
        items: [PlaylistItem],
        failWrites: Bool = false,
        canWriteBack: Bool = true,
        albumsHaveDates: Bool = true,
        albumsRefused: Bool = false
    ) {
        self.items = items
        self.failWrites = failWrites
        self.canWriteBack = canWriteBack
        self.albumsHaveDates = albumsHaveDates
        self.albumsRefused = albumsRefused
    }

    func currentUser() async throws -> SpotifyUser { SpotifyUser(id: "me", displayName: "Me") }

    func playlists(onBatch: @Sendable ([Playlist], Int?) async -> Void) async throws -> [Playlist] { [] }

    func playlistItems(
        playlistID: String,
        ownerID: String,
        onPage: @Sendable ([PlaylistItem], Int) async -> Void
    ) async throws -> [PlaylistItem] {
        itemRequests.append(playlistID)
        await onPage(items, items.count)
        return items
    }

    func albums(ids: [String]) async throws -> [TrackAlbum] {
        albumRequests.append(ids)
        // What a Client ID registered after 2024 gets: the endpoint is not the
        // app's to call, and no retry changes that.
        if albumsRefused { throw SpotifyAPIError.http(status: 403, message: "Forbidden") }
        guard albumsHaveDates else { return [] }
        return ids.map { TrackAlbum(id: $0, name: "Album \($0)", releaseDate: "2019-05-0\(($0.count % 9) + 1)") }
    }

    func createPlaylist(userID: String, name: String, isPublic: Bool, description: String) async throws -> Playlist {
        createdPlaylists.append((name, isPublic, description))
        return Playlist(
            id: "new-playlist", name: name, uri: "spotify:playlist:new",
            owner: PlaylistOwner(id: userID), tracks: PlaylistTrackCount(total: 0)
        )
    }

    func replaceTracks(playlistID: String, uris: [String]) async throws {
        if failWrites { throw SpotifyAPIError.http(status: 403, message: "Forbidden") }
        writes.append((playlistID, uris))
    }
}

/// Serves a fixed lookup table, and nothing for anything absent from it - the
/// shape a real provider has, where coverage is partial.
struct StubFeatureProvider: AudioFeatureProviding {
    let displayName = "Stub"
    let table: [String: AudioFeatures]
    let reason: String?

    init(table: [String: AudioFeatures] = [:], reason: String? = nil) {
        self.table = table
        self.reason = reason
    }

    var unavailabilityReason: String? { get async { reason } }

    func features(forTrackIDs trackIDs: [String]) async throws -> [String: AudioFeatures] {
        table.filter { trackIDs.contains($0.key) }
    }
}

// MARK: - Fixtures

/// A playlist page as Spotify actually returns one - the album inside each track
/// carrying its own `release_date`, because Spotify's simplified album always
/// does. `nestedReleaseDates: false` is the album that somehow arrived without
/// one, which is what the `/albums` gap-filler exists for.
func sampleItems(count: Int, nestedReleaseDates: Bool = true) -> [PlaylistItem] {
    (0..<count).map { index in
        let albumID = "alb\(index % 4)"
        return PlaylistItem(
            addedAt: "2024-0\((index % 9) + 1)-01T00:00:00Z",
            isLocal: false,
            track: Playable(
                id: "t\(index)",
                name: "Track \(index)",
                uri: "spotify:track:t\(index)",
                durationMS: 180_000 + index * 1_000,
                popularity: 40 + index,
                artists: [TrackArtist(name: "Artist \(index % 3)")],
                album: TrackAlbum(
                    id: albumID,
                    releaseDate: nestedReleaseDates ? "20\(10 + index % 4)-0\((index % 4) + 1)-14" : nil
                ),
                type: .track
            )
        )
    }
}

func sampleFeatures(count: Int) -> [String: AudioFeatures] {
    var table: [String: AudioFeatures] = [:]
    for index in 0..<count {
        table["t\(index)"] = AudioFeatures(
            id: "t\(index)",
            tempo: Double(180 - index * 5),
            energy: Double(index) / Double(count),
            danceability: 0.5,
            loudness: -6,
            valence: 0.4,
            acousticness: 0.2
        )
    }
    return table
}

func samplePlaylist(
    ownerID: String = "me",
    isPublic: Bool = false,
    description: String? = "Original",
    total: Int = 8
) -> Playlist {
    Playlist(
        id: "p1", name: "Test Playlist", uri: "spotify:playlist:p1",
        owner: PlaylistOwner(id: ownerID, displayName: "Owner"),
        tracks: PlaylistTrackCount(total: total),
        isPublic: isPublic, rawDescription: description
    )
}
