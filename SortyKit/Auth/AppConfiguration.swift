import Foundation

// `ServiceMode` used to live here, choosing between a bundled sample catalogue
// and a real account. ADR-0007 removed Demo Mode from the shipped app, so there
// is one backend and nothing to choose. The demo catalogue survives under
// `#if DEBUG` for the tests and the screenshot harness, selected by a launch
// argument rather than by a persisted user preference - a stored mode is exactly
// how a demo path survives into a release build unnoticed.

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
            "Spotify restricted this endpoint in November 2024. It works only if your Client ID was granted extended quota before then. Otherwise every request returns 403."
        case .none:
            "BPM, Energy, Danceability, Loudness, Valence and Acousticness stay empty. Every other arrangement works normally."
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
    public var featureSource: FeatureSourceMode

    public static let defaultRedirectURI = "sorty://callback"

    public init(
        clientID: String = "",
        redirectURI: String = AppConfiguration.defaultRedirectURI,
        featureSource: FeatureSourceMode = .reccoBeats
    ) {
        self.clientID = clientID
        self.redirectURI = redirectURI
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

/// Persists `AppConfiguration`. Only the Client ID and preferences live here -
/// tokens go to the Keychain.
public struct ConfigurationStore {
    private let defaults: UserDefaults

    private enum Key {
        static let clientID = "sorty.clientID"
        static let redirectURI = "sorty.redirectURI"
        static let featureSource = "sorty.featureSource"
        /// Written by every version before ADR-0007. Removed on load rather than
        /// left behind, so an install that once chose Demo Mode does not carry a
        /// key naming a mode the app no longer has.
        static let retiredServiceMode = "sorty.serviceMode"
    }

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> AppConfiguration {
        defaults.removeObject(forKey: Key.retiredServiceMode)
        return AppConfiguration(
            clientID: defaults.string(forKey: Key.clientID) ?? "",
            redirectURI: defaults.string(forKey: Key.redirectURI) ?? AppConfiguration.defaultRedirectURI,
            featureSource: defaults.string(forKey: Key.featureSource).flatMap(FeatureSourceMode.init) ?? .reccoBeats
        )
    }

    public func save(_ configuration: AppConfiguration) {
        defaults.set(configuration.clientID, forKey: Key.clientID)
        defaults.set(configuration.redirectURI, forKey: Key.redirectURI)
        defaults.set(configuration.featureSource.rawValue, forKey: Key.featureSource)
    }
}
