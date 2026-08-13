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

    /// **"Open" is the trailing glyph's job, not the label's.**
    /// "Open Spotify Developer Dashboard" measured about 269pt at `.body`
    /// against roughly 263pt of available title width, so it wrapped by six
    /// points at the *default* text size - and `SettingsRowLabel` centres its
    /// leading glyph, which then floated in the gutter beside neither line. The
    /// row already ends in `SettingsExternalIcon`, which says "this leaves the
    /// app" more precisely than the word did.
    public static let openDashboard = "Spotify Developer Dashboard"

    /// The procedure, as a procedure.
    ///
    /// "Character for character" rather than a bolded *exactly*, which is the
    /// same instruction surviving the loss of the formatting that carried it.
    ///
    /// No longer opens with "Create an app on the Spotify dashboard, then paste
    /// its Client ID here": the field's own prompt directly above already reads
    /// "Paste from the Spotify dashboard", and of the two the prompt is the one
    /// in the right place.
    public static let spotifyAppSetup = """
        On the Spotify dashboard: create an app, register the redirect URI above \
        character for character, then add your own account under Users Management.
        """

    /// **Twelve words, from fifty-two.**
    ///
    /// What went: the https-versus-custom-scheme troubleshooting, which is only
    /// relevant if the dashboard actually rejects the URI and which now lives in
    /// `FAQText.limits` where a reader goes *after* hitting the problem rather
    /// than before. A form is not the place to pre-empt a failure that usually
    /// does not happen.
    public static let spotifyAppLimits =
        "A development-mode app admits five listeners, and its owner needs Spotify Premium."

    // MARK: - Audio features

    public static let featureSourceProvider = "Provider"

    public static let featureSourcePrivacy = """
        Track IDs for the playlist you open are sent to api.reccobeats.com. \
        Nothing else leaves the device: not your name, not your tokens.
        """

    /// **Above the card, because the "why" belongs before the choice.**
    ///
    /// This replaces a 49-word footer that restated three things the option rows
    /// below it already said - the November 2024 restriction (the Spotify row's
    /// own first sentence), the six columns, and that ReccoBeats is the default
    /// (the checkmark says so). A footer that repeats the card above it is the
    /// single biggest reason that screen read as a wall of grey.
    ///
    /// It also drops a number that was wrong, and the drop has since paid for
    /// itself twice. "The other nine columns come straight from Spotify" was not
    /// checkable against the model - `Attribute` had thirteen cases, six of them
    /// audio features, which left seven; nine was the count of non-feature
    /// *arrangements*, a different thing wearing the word "columns". ADR-0026
    /// then removed Popularity and the true figure moved again. A sentence with
    /// no count in it needed no edit either time.
    public static let featureSourceLead = """
        BPM, Energy, Danceability, Loudness, Valence and Acousticness need an \
        outside source. Every other arrangement comes from Spotify.
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
