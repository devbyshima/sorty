import Foundation

/// Everything Sorty needs from a music backend.
///
/// Kept as a protocol so the tests and the screenshot harness can run the whole
/// app against bundled sample data with no network and no Spotify credentials.
/// That sample implementation is `#if DEBUG` only - see ADR-0007.
public protocol MusicService: Sendable {
    func currentUser() async throws -> SpotifyUser

    /// Streams playlists page by page; `onBatch` receives everything loaded so
    /// far plus the reported total, so the UI can show real progress.
    func playlists(onBatch: @Sendable ([Playlist], Int?) async -> Void) async throws -> [Playlist]

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

    func playlists(onBatch: @Sendable ([Playlist], Int?) async -> Void) async throws -> [Playlist] {
        await onBatch([], 0)
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
