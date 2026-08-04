import Foundation
import Observation

/// Owns the signed-in state, the configured backend, and the playlist list.
@MainActor
@Observable
public final class SessionModel {
    public enum Stage: Equatable {
        case signedOut
        case connecting
        case signedIn
        case failed(String)
    }

    public private(set) var stage: Stage = .signedOut
    public private(set) var user: SpotifyUser?
    public private(set) var playlists: [Playlist] = []
    public private(set) var playlistLoad: PlaylistLoad = .idle
    public private(set) var featureSourceNotice: String?

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
    public func restore() async {
        switch configuration.serviceMode {
        case .demo:
            await enterDemo()

        case .spotify:
            guard let authenticator, await authenticator.isSignedIn else {
                stage = .signedOut
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

    public func handleAuthCallback(url: URL) async {
        guard let authenticator else { return }
        stage = .connecting
        do {
            try await authenticator.handleCallback(url: url)
            await completeSignIn()
        } catch {
            stage = .failed(error.localizedDescription)
        }
    }

    public func signInFailed(_ error: any Error) {
        if let authError = error as? SpotifyAuthError, authError == .cancelled {
            stage = .signedOut
        } else {
            stage = .failed(error.localizedDescription)
        }
    }

    private func completeSignIn() async {
        stage = .connecting
        do {
            user = try await service.currentUser()
            stage = .signedIn
            featureSourceNotice = await featureProvider.unavailabilityReason
            await loadPlaylists()
        } catch {
            stage = .failed(error.localizedDescription)
        }
    }

    public func signOut() async {
        loadTask?.cancel()
        await authenticator?.signOut()
        user = nil
        playlists = []
        playlistLoad = .idle
        searchText = ""
        categoryFilter = .all
        stage = .signedOut
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

    public func makeTrackTableModel(for playlist: Playlist) -> TrackTableModel {
        TrackTableModel(
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
