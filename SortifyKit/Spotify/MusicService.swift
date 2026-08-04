import Foundation

/// Everything Sortify needs from a music backend.
///
/// Kept as a protocol so the whole app can run against bundled sample data with
/// no network and no Spotify credentials — that's what makes the UI testable
/// and what Demo Mode uses.
public protocol MusicService: Sendable {
    func currentUser() async throws -> SpotifyUser

    /// Streams playlists page by page; `onBatch` receives everything loaded so
    /// far plus the reported total, so the UI can show real progress.
    func playlists(onBatch: @Sendable ([Playlist], Int?) async -> Void) async throws -> [Playlist]

    /// Streams playlist entries page by page.
    func playlistItems(
        playlistID: String,
        ownerID: String,
        onPage: @Sendable ([PlaylistItem], Int) async -> Void
    ) async throws -> [PlaylistItem]

    /// Full album objects, which — unlike the album stub on a track — carry the
    /// release date.
    func albums(ids: [String]) async throws -> [TrackAlbum]

    func createPlaylist(
        userID: String,
        name: String,
        isPublic: Bool,
        description: String
    ) async throws -> Playlist

    /// Replaces a playlist's contents with exactly `uris`, in order.
    func replaceTracks(playlistID: String, uris: [String]) async throws

    /// Whether saving back to Spotify is possible at all. False in demo mode.
    var canWriteBack: Bool { get }
}

public extension MusicService {
    var canWriteBack: Bool { true }
}
