import Foundation

/// Which backend the app is currently talking to.
public enum ServiceMode: String, Sendable, CaseIterable, Hashable {
    /// Bundled sample catalogue — no account, no network, everything populated.
    case demo
    /// A real Spotify account via the user's own Client ID.
    case spotify

    public var label: String {
        switch self {
        case .demo: "Demo Mode"
        case .spotify: "Spotify"
        }
    }
}

/// Where the acoustic columns get their numbers.
public enum FeatureSourceMode: String, Sendable, CaseIterable, Hashable {
    /// Third-party mirror keyed by Spotify track ID. The default, because it is
    /// the only source that still works for a Spotify app registered today.
    case reccoBeats
    /// Spotify's own endpoint. Only functions for Client IDs granted extended
    /// quota before 27 Nov 2024.
    case spotify
    /// Leave the acoustic columns empty; everything else still sorts.
    case none

    public var label: String {
        switch self {
        case .reccoBeats: "ReccoBeats"
        case .spotify: "Spotify audio features"
        case .none: "None"
        }
    }

    public var explanation: String {
        switch self {
        case .reccoBeats:
            "Free, no account needed, keyed by Spotify track ID. Coverage is strong for catalogue released up to 2024 and thin for 2025-onward releases; missing tracks leave those cells blank."
        case .spotify:
            "Spotify restricted this endpoint in November 2024. It works only if your Client ID was granted extended quota before then — otherwise every request returns 403."
        case .none:
            "BPM, Energy, Dance, Loud, Valence and Acoustic stay empty. The other nine columns sort normally."
        }
    }

    /// Third-party lookups leave the app's own network boundary, so the UI says
    /// so before anyone turns one on.
    public var sendsTrackIDsOffDevice: Bool { self == .reccoBeats }
}

/// User-supplied credentials and preferences.
///
/// The Client ID is deliberately not baked into the binary: a development-mode
/// Spotify app only admits five named users, so a shared ID would lock everyone
/// else out. Each person brings their own.
public struct AppConfiguration: Sendable, Equatable {
    public var clientID: String
    public var redirectURI: String
    public var serviceMode: ServiceMode
    public var featureSource: FeatureSourceMode

    public static let defaultRedirectURI = "sortify://callback"

    public init(
        clientID: String = "",
        redirectURI: String = AppConfiguration.defaultRedirectURI,
        serviceMode: ServiceMode = .demo,
        featureSource: FeatureSourceMode = .reccoBeats
    ) {
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.serviceMode = serviceMode
        self.featureSource = featureSource
    }

    public var hasSpotifyCredentials: Bool {
        !clientID.trimmingCharacters(in: .whitespaces).isEmpty
            && !redirectURI.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var authConfig: SpotifyAuthConfig {
        SpotifyAuthConfig(
            clientID: clientID.trimmingCharacters(in: .whitespaces),
            redirectURI: redirectURI.trimmingCharacters(in: .whitespaces)
        )
    }
}

/// Persists `AppConfiguration`. Only the Client ID and preferences live here —
/// tokens go to the Keychain.
public struct ConfigurationStore {
    private let defaults: UserDefaults

    private enum Key {
        static let clientID = "sortify.clientID"
        static let redirectURI = "sortify.redirectURI"
        static let serviceMode = "sortify.serviceMode"
        static let featureSource = "sortify.featureSource"
    }

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> AppConfiguration {
        AppConfiguration(
            clientID: defaults.string(forKey: Key.clientID) ?? "",
            redirectURI: defaults.string(forKey: Key.redirectURI) ?? AppConfiguration.defaultRedirectURI,
            serviceMode: defaults.string(forKey: Key.serviceMode).flatMap(ServiceMode.init) ?? .demo,
            featureSource: defaults.string(forKey: Key.featureSource).flatMap(FeatureSourceMode.init) ?? .reccoBeats
        )
    }

    public func save(_ configuration: AppConfiguration) {
        defaults.set(configuration.clientID, forKey: Key.clientID)
        defaults.set(configuration.redirectURI, forKey: Key.redirectURI)
        defaults.set(configuration.serviceMode.rawValue, forKey: Key.serviceMode)
        defaults.set(configuration.featureSource.rawValue, forKey: Key.featureSource)
    }
}
