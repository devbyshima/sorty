import Foundation

/// Where "Open on Spotify" actually goes.
///
/// **A universal link, never the `spotify:` scheme, and the difference is a
/// system alert.** Spotify's objects carry a URI like `spotify:track:0eGsy…`,
/// and opening a custom scheme makes iOS interrupt with *"Open in Spotify?"* -
/// a confirmation the listener has to dismiss before anything happens, on a
/// button whose entire label is already the answer. There is no API to suppress
/// it; it is the price of the scheme.
///
/// `https://open.spotify.com/track/0eGsy…` is the same destination as a
/// universal link. iOS hands it straight to Spotify with no alert, and where
/// Spotify is not installed it opens the web player instead of failing silently
/// - which is what a custom scheme does when nothing claims it.
public enum SpotifyLink {

    private static let host = "https://open.spotify.com"

    /// The web URL for a Spotify URI.
    ///
    /// Returns nil rather than guessing for anything that is not a URI Spotify
    /// would recognise - a local file has no server-side object and therefore no
    /// page to open.
    public static func url(forURI uri: String) -> URL? {
        let parts = uri.split(separator: ":").map(String.init)

        // `spotify:track:ID`, and every other object of that shape.
        if parts.count == 3, parts[0] == "spotify" {
            return url(kind: parts[1], id: parts[2])
        }

        // `spotify:user:{name}:playlist:{id}` - the owner-scoped spelling
        // Spotify used for years and still emits in places. The trailing pair is
        // the object; the user in the middle is not part of the web URL.
        if parts.count == 5, parts[0] == "spotify", parts[1] == "user" {
            return url(kind: parts[3], id: parts[4])
        }

        // Already a web URL, which is what a caller holding a playlist's
        // `external_urls` would have.
        if uri.hasPrefix("https://open.spotify.com/") { return URL(string: uri) }

        return nil
    }

    /// The service itself, for a link that has no particular object to point at.
    public static var home: URL { URL(string: host)! }

    private static func url(kind: String, id: String) -> URL? {
        // An allowlist rather than anything-goes: a URI Sorty does not
        // understand should fall back to nothing rather than build a URL that
        // 404s on the web. `local` is the one that matters - Spotify uses
        // `spotify:local:…` for files it does not host, and there is no page.
        let known = ["track", "episode", "playlist", "album", "artist", "show"]
        guard known.contains(kind), !id.isEmpty else { return nil }
        return URL(string: "\(host)/\(kind)/\(id)")
    }
}
