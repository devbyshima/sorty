import Foundation

/// Who Sorty is a port of, and where to find them.
///
/// Not an ornamental about box. Sorty exists because Paul Lamere built Sort Your
/// Music in 2012 and it has been sorting playlists on the web ever since;
/// naming him is the *point* of this screen rather than a footnote on it. The
/// credit used to be three lines at the foot of the FAQ, below fourteen
/// collapsed questions, inside a sheet opened from another sheet - which is a
/// credit nobody would ever find.
public enum CreditsText {
    public static let title = "Credits"

    /// Force-unwrapped for the reason `SpotifyLinks` force-unwraps its own: a
    /// literal that does not parse is a mistake on this line, not a state the
    /// app can be in at runtime.
    public static let sortYourMusicURL = URL(string: "https://github.com/plamere/SortYourMusic")!
    public static let paulLamereURL = URL(string: "https://github.com/plamere")!
    public static let sortyURL = URL(string: "https://github.com/devbyshima/sorty")!

    public static let origin = """
        Sorty is an iOS port of Sort Your Music, which Paul Lamere built in 2012 \
        and which has been sorting playlists on the web ever since. The idea - \
        that a playlist reads better ordered by what the music is doing than by \
        when you happened to add it - is his.
        """

    public static let sortYourMusicLink = "Sort Your Music on GitHub"
    public static let paulLamereLink = "Paul Lamere on GitHub"
    public static let sortyLink = "Sorty on GitHub"

    /// Required wherever Spotify's marks and metadata appear, and true besides.
    public static let notAffiliated = "Not affiliated with or endorsed by Spotify."
}
