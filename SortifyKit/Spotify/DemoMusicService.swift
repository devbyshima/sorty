import Foundation

#if DEBUG
// Test and screenshot-harness scaffolding only. ADR-0007 removed Demo Mode from
// the shipped app; this whole file compiles out of Release.

/// A complete, offline stand-in for Spotify.
///
/// Sortify needs this for a reason beyond convenience: a newly registered
/// Spotify app can't read audio features at all, and development mode caps an
/// app at five authorised users. Demo Mode lets the app be opened, explored and
/// screenshotted with every column populated and every sort meaningful.
///
/// The catalogue is invented - fictional artists and titles with plausible
/// acoustic values - so no fabricated measurement is ever attributed to a real
/// recording.
public struct DemoMusicService: MusicService, Sendable {
    public let canWriteBack = false
    private let catalog: DemoCatalog
    /// Simulated per-page latency, so progressive loading is visible.
    private let pageDelay: Duration

    public init(catalog: DemoCatalog = .shared, pageDelay: Duration = .milliseconds(120)) {
        self.catalog = catalog
        self.pageDelay = pageDelay
    }

    public func currentUser() async throws -> SpotifyUser {
        SpotifyUser(id: "demo-user", displayName: "Demo Listener")
    }

    public func playlists(onBatch: @Sendable ([Playlist], Int?) async -> Void) async throws -> [Playlist] {
        var delivered: [Playlist] = []
        for page in catalog.playlists.chunked(into: 3) {
            try? await Task.sleep(for: pageDelay)
            try Task.checkCancellation()
            delivered.append(contentsOf: page)
            await onBatch(delivered, catalog.playlists.count)
        }
        return delivered
    }

    public func playlistItems(
        playlistID: String,
        ownerID: String,
        onPage: @Sendable ([PlaylistItem], Int) async -> Void
    ) async throws -> [PlaylistItem] {
        let all = catalog.items(forPlaylist: playlistID)
        var delivered: [PlaylistItem] = []
        for page in all.chunked(into: 25) {
            try? await Task.sleep(for: pageDelay)
            try Task.checkCancellation()
            delivered.append(contentsOf: page)
            await onPage(page, delivered.count)
        }
        return delivered
    }

    public func albums(ids: [String]) async throws -> [TrackAlbum] {
        ids.compactMap { catalog.album(id: $0) }
    }

    public func createPlaylist(
        userID: String,
        name: String,
        isPublic: Bool,
        description: String
    ) async throws -> Playlist {
        throw DemoModeError.readOnly
    }

    public func replaceTracks(playlistID: String, uris: [String]) async throws {
        throw DemoModeError.readOnly
    }
}

public enum DemoModeError: LocalizedError {
    case readOnly

    public var errorDescription: String? {
        "Demo Mode uses a sample catalogue, so there's nothing to save back. Connect a Spotify account to write playlists."
    }
}

/// Feature values for the demo catalogue.
public struct DemoAudioFeatureProvider: AudioFeatureProviding {
    public let displayName = "Demo catalogue"
    private let catalog: DemoCatalog

    public init(catalog: DemoCatalog = .shared) { self.catalog = catalog }

    public var unavailabilityReason: String? { get async { nil } }

    public func features(forTrackIDs trackIDs: [String]) async throws -> [String: AudioFeatures] {
        var result: [String: AudioFeatures] = [:]
        for id in trackIDs {
            if let features = catalog.features(forTrackID: id) { result[id] = features }
        }
        return result
    }
}
#endif
