import Foundation

/// Every word the settings screens say.
///
/// Same reason `EmptyState` and `PlaylistRowText` exist: the copy *is* the
/// design here. Three of these sentences are the only explanation anywhere in
/// the app of why an audio-feature source has to be chosen at all, and a
/// sentence typed into a view is a sentence no test can hold to account.
///
/// **No markdown in any of these.** They are read as `String`, which selects
/// `Text`'s plain overload rather than the `LocalizedStringKey` one a literal
/// gets - so `**exactly**` would reach the screen as four asterisks and a word.
/// The settings copy used to lean on that formatting; the emphasis now lives in
/// the word order, which survives the move and reads aloud better besides.
public enum SettingsText {
    public static let title = "Settings"

    // MARK: - Account

    public static let accountConnected = "Connected to Spotify"
    public static let accountNotConnectedTitle = "Not connected"
    public static let accountNotConnected = "Connect a Spotify account to see your playlists."
    public static let connect = "Connect Spotify"

    /// Spotify sends a display name for most accounts and nothing for some. The
    /// account id is the fallback rather than a placeholder, because it is at
    /// least the thing the listener typed to sign up.
    public static func account(displayName: String?, id: String?) -> String {
        displayName ?? id ?? accountNotConnectedTitle
    }

    public static let signOut = "Sign out"
    public static let signOutConfirmTitle = "Sign out of Spotify?"
    public static let signOutConfirmDetail =
        "Your Client ID stays where it is. Connecting again takes one tap and one authorisation."

    // MARK: - Rows

    public static let appearance = "Appearance"
    public static let appearanceFooter =
        "Light and dark are both designed. System follows whatever your device is set to."
    public static let spotifyApp = "Spotify app"
    public static let spotifyAppUnset = "Not set"
    public static let audioFeatures = "Audio features"
    public static let faq = "Frequently asked questions"
    public static let credits = "Credits"

    // MARK: - Spotify app

    public static let clientID = "Client ID"
    public static let clientIDPrompt = "Paste from the Spotify dashboard"
    public static let redirectURI = "Redirect URI"
    public static let openDashboard = "Open Spotify Developer Dashboard"

    /// "Character for character" rather than a bolded *exactly*, which is the
    /// same instruction surviving the loss of the formatting that carried it.
    public static let spotifyAppSetup = """
        Create an app on the Spotify dashboard, then paste its Client ID here. \
        Register the redirect URI character for character as it appears above, \
        and add your own Spotify account under Users Management.
        """

    public static let spotifyAppLimits = """
        Two limits are worth knowing before you start: a development-mode app \
        admits at most five listeners, and its owner needs Spotify Premium. \
        Spotify's own docs prefer an https redirect over a custom scheme, so if \
        the dashboard rejects the sorty://callback address as insecure, point \
        this at an https URL you control instead.
        """

    // MARK: - Audio features

    public static let featureSourceProvider = "Provider"

    public static let featureSourcePrivacy = """
        Track IDs for the playlist you open are sent to api.reccobeats.com. \
        Nothing else leaves the device: not your name, not your tokens.
        """

    public static let featureSourceRationale = """
        BPM, Energy, Dance, Loud, Valence and Acoustic come from an \
        audio-feature source. Spotify restricted its own audio-features endpoint \
        in November 2024 for every app registered after that date and has \
        published no replacement, so Sorty defaults to ReccoBeats. The other \
        nine columns come straight from Spotify and always work.
        """

    // MARK: - Footer

    public static let madeBy = "Made by Shima at Fulltime"

    /// The build, as one string.
    ///
    /// "Sorty" rather than "Version", because the number is meaningless without
    /// the name beside it in a bug report, and this line is the only place the
    /// two appear together.
    public static func version(short: String, build: String?) -> String {
        build.map { "Sorty \(short) (\($0))" } ?? "Sorty \(short)"
    }
}
