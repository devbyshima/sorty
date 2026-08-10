import Foundation
import Observation

/// Owns the signed-in state, the configured backend, and the playlist list.
@MainActor
@Observable
public final class SessionModel {
    /// There is no signed-out stage, by decision.
    ///
    /// ADR-0003 makes Demo Mode the front door: the app opens into a live
    /// session against the sample catalogue, so a first-run listener is
    /// arranging a real-looking playlist before anything is asked of them.
    /// Signing out, a cancelled authorisation and a failed one all land back
    /// there rather than on a wall. A `signedOut` case would be a state nothing
    /// could reach and a screen nobody could see.
    /// What the root is showing.
    ///
    /// ADR-0003 refused a `signedOut` case on the grounds that Demo Mode meant
    /// a session always existed and such a state would be unreachable. ADR-0007
    /// removed Demo Mode, so it is now the state a first run begins in.
    public enum Stage: Equatable {
        /// Building a session.
        case connecting
        /// No account. The way in, and where signing out lands.
        case signedOut
        /// A connected account, with a library.
        case ready
    }

    public private(set) var stage: Stage = .connecting
    public private(set) var user: SpotifyUser?

    /// Why the last attempt to connect didn't, or nil.
    ///
    /// Carried rather than staged: a failed connection leaves whatever session
    /// existed intact, and this is what the connect flow shows when it is next
    /// opened. Cleared by starting another attempt.
    public private(set) var connectFailure: String?

    /// Whether an account is connected. The one thing the views used to ask
    /// `isDemo` about, asked the way round that still means something.
    public var isConnected: Bool { user != nil }

    #if DEBUG
    /// The screenshot harness and the tests, running against the bundled
    /// catalogue. Never true in a release build - see ADR-0007.
    public let usesDemoData: Bool
    /// `-stallLibrary` and `-stallTracks`, so the harness can photograph a load
    /// in progress. Two, because stalling the library also stalls the harness's
    /// own navigation - see `DemoMusicService`.
    public let demoStall: Duration?
    public let demoTrackStall: Duration?
    #endif
    public private(set) var playlists: [Playlist] = []
    public private(set) var playlistLoad: PlaylistLoad = .idle

    public enum PlaylistLoad: Equatable {
        case idle
        case loading(loaded: Int, total: Int?)
        case ready
        case failed(String)
    }

    public var configuration: AppConfiguration {
        didSet {
            guard configuration != oldValue else { return }
            configurationStore.save(configuration)
            rebuildServices()
        }
    }

    // Playlist list filters
    public var categoryFilter: PlaylistFilter = .all
    public var searchText: String = ""

    /// How the library presents itself. Written straight through to the
    /// preference store on change, so the choice survives a launch without the
    /// view having to remember to save it.
    public var libraryOrder: LibraryOrder {
        didSet { libraryPreferences.order = libraryOrder }
    }

    public var libraryLayout: LibraryLayout {
        didSet { libraryPreferences.layout = libraryLayout }
    }

    private let libraryPreferences: LibraryPreferences

    /// Playlists Spotify listed and would not describe, this load.
    ///
    /// Nulls in `/me/playlists`. They used to be compacted away, so a library
    /// could be four playlists short and say nothing about it - see
    /// `LibraryNotice.withheldFromListing` for what the library says now, and
    /// ADR-0018 for why it says it at the foot rather than the head.
    public private(set) var withheldPlaylistCount = 0

    /// Where the launch is up to, in the terms the splash gate reasons in.
    ///
    /// The mapping lives here, beside the state it reads, so that
    /// `LaunchReadiness` stays a pure truth table isolated to nothing.
    public var launchProgress: LaunchReadiness.Progress {
        switch stage {
        case .connecting: .connecting
        case .signedOut: .signedOut
        case .ready:
            switch playlistLoad {
            case .idle: .libraryIdle
            case .loading(let loaded, _): .libraryLoading(loaded: loaded)
            case .ready: .libraryReady
            case .failed: .libraryFailed
            }
        }
    }

    private let configurationStore: ConfigurationStore
    private let tokenStore: any TokenStoring
    private var loadTask: Task<Void, Never>?

    public private(set) var service: any MusicService
    public private(set) var featureProvider: any AudioFeatureProviding
    public private(set) var authenticator: SpotifyAuthenticator?

    #if DEBUG
    public init(
        configurationStore: ConfigurationStore = ConfigurationStore(),
        tokenStore: any TokenStoring = KeychainTokenStore(),
        libraryPreferences: LibraryPreferences = LibraryPreferences(),
        usesDemoData: Bool = false,
        demoStall: Duration? = nil,
        demoTrackStall: Duration? = nil
    ) {
        self.usesDemoData = usesDemoData
        self.demoStall = demoStall
        self.demoTrackStall = demoTrackStall
        let configuration = configurationStore.load()
        self.configurationStore = configurationStore
        self.tokenStore = tokenStore
        self.configuration = configuration
        self.libraryPreferences = libraryPreferences
        self.libraryOrder = libraryPreferences.order
        self.libraryLayout = libraryPreferences.layout
        self.service = UnconnectedMusicService()
        self.featureProvider = NoAudioFeatureProvider()
        rebuildServices()
    }
    #else
    public init(
        configurationStore: ConfigurationStore = ConfigurationStore(),
        tokenStore: any TokenStoring = KeychainTokenStore(),
        libraryPreferences: LibraryPreferences = LibraryPreferences()
    ) {
        let configuration = configurationStore.load()
        self.configurationStore = configurationStore
        self.tokenStore = tokenStore
        self.configuration = configuration
        self.libraryPreferences = libraryPreferences
        self.libraryOrder = libraryPreferences.order
        self.libraryLayout = libraryPreferences.layout
        self.service = UnconnectedMusicService()
        self.featureProvider = NoAudioFeatureProvider()
        rebuildServices()
    }
    #endif

    // MARK: - Wiring

    private func rebuildServices() {
        loadTask?.cancel()

        #if DEBUG
        // The one way into the sample catalogue, and it is a launch argument
        // rather than a stored preference: a persisted mode is how a demo path
        // survives into a release build unnoticed, and it cannot be reached by
        // a listener at all. See ADR-0007.
        if usesDemoData {
            authenticator = nil
            service = DemoMusicService(stall: demoStall, trackStall: demoTrackStall)
            featureProvider = DemoAudioFeatureProvider()
            return
        }
        #endif

        guard configuration.hasSpotifyCredentials else {
            // No Client ID yet. Not an error and not a fallback catalogue - the
            // app simply has no account, which the signed-out stage says.
            authenticator = nil
            service = UnconnectedMusicService()
            featureProvider = NoAudioFeatureProvider()
            return
        }
        let auth = SpotifyAuthenticator(config: configuration.authConfig, store: tokenStore)
        authenticator = auth
        service = SpotifyMusicService(auth: auth)
        featureProvider = switch configuration.featureSource {
        case .reccoBeats: ReccoBeatsAudioFeatureProvider()
        case .spotify: SpotifyAudioFeatureProvider(auth: auth)
        case .none: NoAudioFeatureProvider()
        }
    }

    // MARK: - Session lifecycle

    /// What happens on launch.
    ///
    /// A remembered connection is resumed, so setup stays a one-time cost.
    /// Anything else - never connected, tokens gone, connection now refused -
    /// lands signed out. ADR-0003 used to send all of those into Demo Mode so
    /// nobody met a wall on launch; ADR-0007 accepts the wall, because the
    /// demonstration was against playlists that were never the listener's.
    public func restore() async {
        #if DEBUG
        if usesDemoData {
            await completeSignIn()
            return
        }
        #endif

        guard let authenticator, await authenticator.isSignedIn else {
            stage = .signedOut
            return
        }
        await completeSignIn()
    }

    /// The URL to open in `ASWebAuthenticationSession`. Nil when unconfigured.
    public func authorizationURL() async -> URL? {
        await authenticator?.makeAuthorizationURL()
    }

    /// Clears whatever the last attempt failed with, so a retry doesn't open
    /// under an error it has already moved past.
    public func beginConnecting() {
        connectFailure = nil
    }

    public func handleAuthCallback(url: URL) async {
        guard let authenticator else { return }
        stage = .connecting
        do {
            try await authenticator.handleCallback(url: url)
            await completeSignIn()
        } catch {
            await failToConnect(error.localizedDescription)
        }
    }

    /// A cancelled sheet is not a failure - the listener simply changed their
    /// mind, and lands back where they were with nothing to explain.
    public func signInFailed(_ error: any Error) async {
        if let authError = error as? SpotifyAuthError, authError == .cancelled {
            stage = signedInStage
        } else {
            await failToConnect(error.localizedDescription)
        }
    }

    private func failToConnect(_ message: String) async {
        stage = signedOutStageAfterFailure
        // Set after the stage, which clears nothing else - this is the only
        // trace the attempt leaves.
        connectFailure = message
    }

    /// Where a cancelled attempt lands: back in the library if one was already
    /// connected, otherwise signed out.
    private var signedInStage: Stage { user == nil ? .signedOut : .ready }

    /// A failed attempt cannot leave a half-session on screen. If an account was
    /// already working it stays; otherwise there is nothing to show but the way
    /// in, now carrying an explanation.
    private var signedOutStageAfterFailure: Stage { user == nil ? .signedOut : .ready }

    private func completeSignIn() async {
        stage = .connecting
        do {
            user = try await service.currentUser()
            stage = .ready
            await loadPlaylists()
        } catch {
            // A configured account that can't be reached falls back rather than
            // stranding the listener. In Demo Mode `currentUser` cannot throw,
            // so this cannot recurse.
            #if DEBUG
            if usesDemoData {
                stage = .ready
                return
            }
            #endif
            await failToConnect(error.localizedDescription)
        }
    }

    /// Lands signed out, which is where a first run begins too.
    public func signOut() async {
        loadTask?.cancel()
        await authenticator?.signOut()
        user = nil
        playlists = []
        playlistLoad = .idle
        searchText = ""
        categoryFilter = .all
        connectFailure = nil
        stage = .signedOut
        rebuildServices()
    }

    // MARK: - Playlists

    public func loadPlaylists() async {
        loadTask?.cancel()
        playlistLoad = .loading(loaded: 0, total: nil)
        playlists = []
        withheldPlaylistCount = 0

        let task = Task { [service] in
            let sink = PlaylistSink()
            do {
                _ = try await service.playlists { listing in
                    await sink.update(listing)
                    let snapshot = await sink.snapshot
                    await MainActor.run {
                        self.playlists = snapshot.playlists
                        self.withheldPlaylistCount = snapshot.withheldCount
                        self.playlistLoad = .loading(loaded: snapshot.playlists.count, total: snapshot.total)
                    }
                }
                await MainActor.run { self.playlistLoad = .ready }
            } catch is CancellationError {
                // Superseded by a newer load.
            } catch {
                await MainActor.run { self.playlistLoad = .failed(error.localizedDescription) }
            }
        }
        loadTask = task
        await task.value
    }

    // MARK: - Filtering

    public var filteredPlaylists: [Playlist] {
        libraryOrder.apply(to: matchingPlaylists)
    }

    /// Filtered but unordered. Split out so the ordering is applied exactly
    /// once, to the set that survived the filter, rather than to the whole
    /// library before it is narrowed.
    private var matchingPlaylists: [Playlist] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return playlists.filter { playlist in
            let nameOK = query.isEmpty || playlist.name.lowercased().contains(query)
            return categoryFilter.matches(playlist, currentUserID: user?.id) && nameOK
        }
    }

    public func count(for filter: PlaylistFilter) -> Int {
        playlists.filter { filter.matches($0, currentUserID: user?.id) }.count
    }

    public func makeTrackListModel(for playlist: Playlist) -> TrackListModel {
        TrackListModel(
            playlist: playlist,
            service: service,
            featureProvider: featureProvider,
            currentUserID: user?.id
        )
    }
}

public enum PlaylistFilter: Hashable, Sendable, Identifiable, CaseIterable {
    case all
    case category(PlaylistCategory)

    /// Four chips that partition the library by who owns what, and nothing else.
    ///
    /// There was a Personalized chip once. It went when `.personalized` and
    /// `.spotify` merged (ADR-0018): the two were told apart by an undocumented
    /// id prefix that did not match Discover Weekly, and Discover Weekly and the
    /// Daily Mixes are Spotify's playlists in every sense a listener cares
    /// about anyway.
    ///
    /// There was a Collaborative chip too, and removing it stranded nothing
    /// (ADR-0017). Collaboration was never a category - it is an axis crossing
    /// all of them, which is why a chip for it sat oddly beside three that
    /// partition. A shared playlist you own is still filed under Mine and one
    /// Sam owns under Others.
    public static var allCases: [PlaylistFilter] {
        [.all, .category(.mine), .category(.spotify), .category(.other)]
    }

    /// The one place a filter decides what it covers.
    ///
    /// Previously the list and the counts each carried their own copy of this
    /// switch, which is exactly the shape of thing that drifts: a filter could
    /// show four playlists while its chip claimed five.
    public func matches(_ playlist: Playlist, currentUserID: String?) -> Bool {
        switch self {
        case .all:
            return true
        case .category(let category):
            return playlist.category(currentUserID: currentUserID) == category
        }
    }

    public var id: String {
        switch self {
        case .all: "all"
        case .category(let category): category.rawValue
        }
    }

    public var label: String {
        switch self {
        case .all: "All"
        case .category(.other): "Others"
        case .category(let category): category.label
        }
    }
}

/// Off-actor accumulator for the streaming playlist load.
private actor PlaylistSink {
    private var listing = PlaylistListing()

    var snapshot: PlaylistListing { listing }

    func update(_ batch: PlaylistListing) {
        listing = batch
    }
}
