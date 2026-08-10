import Foundation

/// What the library listing amounts to so far.
///
/// Three values rather than an array, because one of them is an absence.
/// Spotify's listing can carry entries it declines to describe - a `null` where
/// a playlist object should be - and a null has no id, no name and no cover, so
/// there is no row to draw for it. It can still be counted, and counting it is
/// the difference between a library that is quietly missing four playlists and
/// one that says four are missing. ADR-0018.
public struct PlaylistListing: Sendable, Equatable {
    public var playlists: [Playlist]
    /// What Spotify says the library holds.
    ///
    /// Not the yardstick for what was withheld: it is a count of a set that can
    /// change under a paged read, so subtracting from it would invent a
    /// shortfall for anyone who made a playlist mid-load. The nulls are directly
    /// observed, and that is what `withheldCount` reports.
    public var total: Int?
    /// Entries Spotify listed and would not describe, across every page so far.
    public var withheldCount: Int

    public init(playlists: [Playlist] = [], total: Int? = nil, withheldCount: Int = 0) {
        self.playlists = playlists
        self.total = total
        self.withheldCount = withheldCount
    }
}

/// Everything Sorty needs from a music backend.
///
/// Kept as a protocol so the tests and the screenshot harness can run the whole
/// app against bundled sample data with no network and no Spotify credentials.
/// That sample implementation is `#if DEBUG` only - see ADR-0007.
public protocol MusicService: Sendable {
    func currentUser() async throws -> SpotifyUser

    /// Streams playlists page by page; `onBatch` receives everything loaded so
    /// far, so the UI can fill as the pages land.
    func playlists(onBatch: @Sendable (PlaylistListing) async -> Void) async throws -> [Playlist]

    /// Streams playlist entries page by page.
    ///
    /// `ownerID` is context, not a path component. The reference app reads
    /// `/users/{owner}/playlists/{id}/tracks`, and that owner-scoped spelling is
    /// what this parameter is a remnant of; February 2026 removed the
    /// `/users/{id}/playlists` family outright, so building a URL from it now
    /// would 404. Whether Spotify will hand the contents over is decided by
    /// `Playlist.contentsAreReadable(byUserID:)` before this is called at all.
    func playlistItems(
        playlistID: String,
        ownerID: String,
        onPage: @Sendable ([PlaylistItem], Int) async -> Void
    ) async throws -> [PlaylistItem]

    /// Full album objects, asked for only when an album arrived without a release
    /// date. A track carries its album's `release_date` already, so this is a
    /// gap-filler rather than the way release dates are read - see
    /// `TrackRow.albumReleaseDate` for the bug that assumption caused.
    func albums(ids: [String]) async throws -> [TrackAlbum]

    func createPlaylist(
        userID: String,
        name: String,
        isPublic: Bool,
        description: String
    ) async throws -> Playlist

    /// Replaces a playlist's contents with exactly `uris`, in order.
    func replaceTracks(playlistID: String, uris: [String]) async throws

    /// Whether saving back to Spotify is possible at all. False for any session
    /// that is not a connected account.
    var canWriteBack: Bool { get }
}

public extension MusicService {
    var canWriteBack: Bool { true }
}


/// What `SessionModel` holds before a Spotify account is connected.
///
/// A stand-in rather than an optional, so every call site keeps compiling and
/// no view has to learn about a nil service. It answers "no account" to
/// everything and writes nothing.
///
/// It replaces a `DemoMusicService` that used to fill this role, which is how a
/// listener with no Client ID ended up looking at seven invented playlists and
/// wondering whose they were.
struct UnconnectedMusicService: MusicService {
    struct NotConnected: LocalizedError {
        var errorDescription: String? { "Connect a Spotify account first." }
    }

    var canWriteBack: Bool { false }

    func currentUser() async throws -> SpotifyUser { throw NotConnected() }

    func playlists(onBatch: @Sendable (PlaylistListing) async -> Void) async throws -> [Playlist] {
        await onBatch(PlaylistListing(total: 0))
        return []
    }

    func playlistItems(
        playlistID: String,
        ownerID: String,
        onPage: @Sendable ([PlaylistItem], Int) async -> Void
    ) async throws -> [PlaylistItem] { [] }

    func albums(ids: [String]) async throws -> [TrackAlbum] { [] }

    func createPlaylist(
        userID: String,
        name: String,
        isPublic: Bool,
        description: String
    ) async throws -> Playlist { throw NotConnected() }

    func replaceTracks(playlistID: String, uris: [String]) async throws { throw NotConnected() }
}
