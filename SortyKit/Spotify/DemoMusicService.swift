import Foundation

#if DEBUG
// Test and screenshot-harness scaffolding only. ADR-0007 removed Demo Mode from
// the shipped app; this whole file compiles out of Release.

/// A complete, offline stand-in for Spotify.
///
/// Sorty needs this for a reason beyond convenience: a newly registered
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
    /// Extra latency per page beyond the first, from `-stallLibrary`.
    ///
    /// The skeletons of ADR-0019 exist only while pages are in flight, and
    /// against a bundled catalogue every page has landed long before a
    /// screenshot could be taken - so the state they exist for is one no shot
    /// could ever catch. Same problem `-pendingCovers` solves, same answer.
    private let stall: Duration?
    /// Extra latency before a playlist's contents, from `-stallTracks`.
    ///
    /// Separate from `stall` because `restore()` awaits the whole library load
    /// and the harness navigates after it - so stalling the library also stalls
    /// the navigation, and a shot asking for the track list never reaches one.
    private let trackStall: Duration?

    public init(
        catalog: DemoCatalog = .shared,
        pageDelay: Duration = .milliseconds(120),
        stall: Duration? = nil,
        trackStall: Duration? = nil
    ) {
        self.catalog = catalog
        self.pageDelay = pageDelay
        self.stall = stall
        self.trackStall = trackStall
    }

    public func currentUser() async throws -> SpotifyUser {
        SpotifyUser(id: DemoCatalog.userID, displayName: "Demo Listener")
    }

    public func playlists(onBatch: @Sendable (PlaylistListing) async -> Void) async throws -> [Playlist] {
        var listing = PlaylistListing(
            total: catalog.playlists.count + DemoCatalog.withheldFromListing,
            withheldCount: DemoCatalog.withheldFromListing
        )
        // The first page still lands promptly, so the launch gate opens on
        // something; what `stall` holds back is everything after it, which is
        // the only window in which the trailing placeholders exist at all.
        var isFirstPage = true
        for page in catalog.playlists.chunked(into: 3) {
            if let stall, !isFirstPage { try? await Task.sleep(for: stall) }
            isFirstPage = false
            try? await Task.sleep(for: pageDelay)
            try Task.checkCancellation()
            listing.playlists.append(contentsOf: page)
            await onBatch(listing)
        }
        return listing.playlists
    }

    public func playlistItems(
        playlistID: String,
        ownerID: String,
        onPage: @Sendable ([PlaylistItem], Int) async -> Void
    ) async throws -> [PlaylistItem] {
        // The same rule Spotify applies. Without it the catalogue opened
        // Discover Weekly on the first try, which is the one thing no listener's
        // Spotify will ever do - so the refusal a listener is most likely to
        // meet was the one screen no fixture could reach and no screenshot could
        // photograph. ADR-0018.
        if let playlist = catalog.playlists.first(where: { $0.id == playlistID }),
           !playlist.contentsAreReadable(byUserID: DemoCatalog.userID) {
            throw SpotifyAPIError.http(status: 404, message: nil)
        }
        let all = catalog.items(forPlaylist: playlistID)
        var delivered: [PlaylistItem] = []
        // Held before the first page rather than after it: `TrackListModel`
        // assigns its rows once, when every page has landed, so the track list
        // has nothing to draw until the whole fetch completes and the skeleton
        // is the only content the screen can have.
        if let trackStall { try? await Task.sleep(for: trackStall) }
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
