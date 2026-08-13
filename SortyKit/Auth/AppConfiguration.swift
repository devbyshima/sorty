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

    /// One option's line, and **a line is what it has to be.**
    ///
    /// These were 25 to 29 words each. Three of them stacked put twelve lines of
    /// identical grey between the listener and a three-way choice, which is the
    /// whole of why the screen read as a wall - the choice was the smallest thing
    /// on a page about making it. Each is now at most two lines at the default
    /// text size, carrying only what distinguishes this option from the other
    /// two.
    ///
    /// What they no longer carry, and where it went instead:
    /// - The six column names. `SettingsText.featureSourceLead` names them once,
    ///   above the card, in `Attribute.name`'s spelling. They used to appear
    ///   twice on one screen in two different vocabularies - "Danceability,
    ///   Loudness, Acousticness" here and "Dance, Loud, Acoustic" in the footer.
    /// - "keyed by Spotify track ID". The privacy note directly beneath says
    ///   which IDs go where, and says it better.
    public var explanation: String {
        switch self {
        case .reccoBeats:
            "Free, no account needed. Coverage is strong up to 2024 and patchy after; missing tracks leave blank cells."
        case .spotify:
            "Only works for a Client ID granted extended quota before November 2024. Every other app is refused."
        case .none:
            "Those six columns stay empty. Every other arrangement still works."
        }
    }

    /// Third-party lookups leave the app's own network boundary, so the UI says
    /// so before anyone turns one on.
    public var sendsTrackIDsOffDevice: Bool { self == .reccoBeats }

    /// The glyph beside this source in the Audio features picker.
    ///
    /// Three shapes rather than three dots, because the list is read once and
    /// then scanned: a waveform, Spotify's own note, and a source switched off.
    public var symbolName: String {
        switch self {
        case .reccoBeats: "waveform"
        case .spotify: "music.note"
        case .none: "slash.circle"
        }
    }
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

    /// The Client ID as it should be *stored*: trimmed.
    ///
    /// `authConfig` already trims on the way out, so an untrimmed store means
    /// the string on screen and the string used are different strings - and a
    /// Client ID pasted from a web page routinely arrives with a trailing
    /// newline on it.
    ///
    /// A function returning a copy rather than a `didSet`, because the settings
    /// field commits on submit rather than on every keystroke: `SessionModel`
    /// rebuilds the entire service stack when `configuration` changes, and
    /// typing a 32-character ID used to do that 32 times.
    public func settingClientID(_ raw: String) -> AppConfiguration {
        var copy = self
        copy.clientID = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }

    /// Emptying the redirect URI restores the default rather than persisting
    /// nothing.
    ///
    /// An empty one makes `hasSpotifyCredentials` false, which unconfigures the
    /// app *silently*: `rebuildServices()` drops the authenticator, the library
    /// carries on working off the token already in hand, and the next launch has
    /// no way back in. There is no reading of "I cleared this field" that means
    /// that.
    public func settingRedirectURI(_ raw: String) -> AppConfiguration {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var copy = self
        copy.redirectURI = trimmed.isEmpty ? AppConfiguration.defaultRedirectURI : trimmed
        return copy
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
