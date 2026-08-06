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
    public enum Stage: Equatable {
        /// Building a session — signing in, or standing up Demo Mode.
        case connecting
        /// A session is live. Demo Mode or a real account; `isDemo` says which.
        case ready
    }

    public private(set) var stage: Stage = .connecting
    public private(set) var user: SpotifyUser?

    /// Why the last attempt to connect didn't, or nil.
    ///
    /// Carried rather than staged: a failed connection drops back into Demo
    /// Mode with the session intact, and this is what the connect flow shows
    /// when it is next opened. Cleared by starting another attempt.
    public private(set) var connectFailure: String?

    /// Whether the live session is the sample catalogue rather than an account.
    public var isDemo: Bool { configuration.serviceMode == .demo }
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

    private let configurationStore: ConfigurationStore
    private let tokenStore: any TokenStoring
    private var loadTask: Task<Void, Never>?

    public private(set) var service: any MusicService
    public private(set) var featureProvider: any AudioFeatureProviding
    public private(set) var authenticator: SpotifyAuthenticator?

    public init(
        configurationStore: ConfigurationStore = ConfigurationStore(),
        tokenStore: any TokenStoring = KeychainTokenStore()
    ) {
        let configuration = configurationStore.load()
        self.configurationStore = configurationStore
        self.tokenStore = tokenStore
        self.configuration = configuration
        self.service = DemoMusicService()
        self.featureProvider = DemoAudioFeatureProvider()
        rebuildServices()
    }

    // MARK: - Wiring

    private func rebuildServices() {
        loadTask?.cancel()

        switch configuration.serviceMode {
        case .demo:
            authenticator = nil
            service = DemoMusicService()
            featureProvider = DemoAudioFeatureProvider()

        case .spotify:
            guard configuration.hasSpotifyCredentials else {
                authenticator = nil
                service = DemoMusicService()
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
    }

    // MARK: - Session lifecycle

    /// Restores an existing session, or drops straight into Demo Mode.
    /// What happens on launch: a session, always.
    ///
    /// A remembered connection is resumed, so setup stays a one-time cost. Any
    /// other outcome — never connected, tokens gone, connection now refused —
    /// is Demo Mode rather than a landing screen, because the alternative is
    /// meeting a wall on launch and ADR-0003 is that the product should
    /// demonstrate itself first.
    public func restore() async {
        switch configuration.serviceMode {
        case .demo:
            await enterDemo()

        case .spotify:
            guard let authenticator, await authenticator.isSignedIn else {
                await enterDemo()
                return
            }
            await completeSignIn()
        }
    }

    public func enterDemo() async {
        configuration.serviceMode = .demo
        stage = .connecting
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

    /// A cancelled sheet is not a failure — the listener simply changed their
    /// mind, and lands back where they were with nothing to explain.
    public func signInFailed(_ error: any Error) async {
        if let authError = error as? SpotifyAuthError, authError == .cancelled {
            await enterDemo()
        } else {
            await failToConnect(error.localizedDescription)
        }
    }

    private func failToConnect(_ message: String) async {
        await enterDemo()
        // After `enterDemo`, which clears nothing else — the session is live
        // and usable, and this is the only trace the attempt leaves.
        connectFailure = message
    }

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
            guard configuration.serviceMode != .demo else {
                stage = .ready
                return
            }
            await failToConnect(error.localizedDescription)
        }
    }

    /// Returns to Demo Mode. There is nowhere else to go.
    public func signOut() async {
        loadTask?.cancel()
        await authenticator?.signOut()
        user = nil
        playlists = []
        playlistLoad = .idle
        searchText = ""
        categoryFilter = .all
        connectFailure = nil
        await enterDemo()
    }

    // MARK: - Playlists

    public func loadPlaylists() async {
        loadTask?.cancel()
        playlistLoad = .loading(loaded: 0, total: nil)
        playlists = []

        let task = Task { [service] in
            let sink = PlaylistSink()
            do {
                _ = try await service.playlists { batch, total in
                    await sink.update(batch, total: total)
                    let snapshot = await sink.snapshot
                    await MainActor.run {
                        self.playlists = snapshot.playlists
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
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return playlists.filter { playlist in
            let categoryOK: Bool
            switch categoryFilter {
            case .all: categoryOK = true
            case .collaborative: categoryOK = playlist.collaborative
            case .category(let category): categoryOK = playlist.category(currentUserID: user?.id) == category
            }
            let nameOK = query.isEmpty || playlist.name.lowercased().contains(query)
            return categoryOK && nameOK
        }
    }

    public func count(for filter: PlaylistFilter) -> Int {
        playlists.filter { playlist in
            switch filter {
            case .all: true
            case .collaborative: playlist.collaborative
            case .category(let category): playlist.category(currentUserID: user?.id) == category
            }
        }.count
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
    case collaborative

    public static var allCases: [PlaylistFilter] {
        [.all, .category(.mine), .category(.personalized), .category(.spotify), .category(.other), .collaborative]
    }

    public var id: String {
        switch self {
        case .all: "all"
        case .collaborative: "collaborative"
        case .category(let category): category.rawValue
        }
    }

    public var label: String {
        switch self {
        case .all: "All"
        case .collaborative: "Collaborative"
        case .category(.other): "Others"
        case .category(let category): category.label
        }
    }
}

/// Off-actor accumulator for the streaming playlist load.
private actor PlaylistSink {
    private var playlists: [Playlist] = []
    private var total: Int?

    var snapshot: (playlists: [Playlist], total: Int?) { (playlists, total) }

    func update(_ batch: [Playlist], total: Int?) {
        playlists = batch
        if let total { self.total = total }
    }
}
