import Foundation
import Testing

/// Where "Open on Spotify" goes, and why it is not the URI.
///
/// The whole of this file is one rule: **never the `spotify:` scheme.** Opening
/// a custom scheme makes iOS put an "Open in Spotify?" confirmation in front of
/// it - a dialog the listener has to dismiss, on a button whose label already
/// answered the question, and one no API can suppress. A universal link is
/// handed straight to the app.
@Suite("Spotify links")
struct SpotifyLinkTests {

    @Test("Every object becomes its web URL, never its URI")
    func objectsBecomeWebURLs() {
        let cases = [
            ("spotify:track:0eGsygTp906u18L0Oimnem", "https://open.spotify.com/track/0eGsygTp906u18L0Oimnem"),
            ("spotify:episode:512ojhOuo1ktJprKbVcKyQ", "https://open.spotify.com/episode/512ojhOuo1ktJprKbVcKyQ"),
            ("spotify:playlist:37i9dQZEVXcJZyENOWUFo7", "https://open.spotify.com/playlist/37i9dQZEVXcJZyENOWUFo7"),
            ("spotify:album:1DFixLWuPkv3KT3TnV35m3", "https://open.spotify.com/album/1DFixLWuPkv3KT3TnV35m3"),
            ("spotify:artist:0OdUWJ0sBjDrqHygGUXeCF", "https://open.spotify.com/artist/0OdUWJ0sBjDrqHygGUXeCF"),
        ]
        for (uri, expected) in cases {
            #expect(SpotifyLink.url(forURI: uri) == URL(string: expected), "\(uri) did not become a web URL")
        }
    }

    /// Nothing may come back carrying the scheme, whatever the input shape -
    /// this is the assertion that would catch a future "just pass the URI
    /// through" fallback.
    @Test("No link ever carries the spotify scheme")
    func neverTheScheme() {
        let inputs = [
            "spotify:track:t1",
            "spotify:user:sam:playlist:p1",
            "https://open.spotify.com/track/t1",
        ]
        for input in inputs {
            let url = SpotifyLink.url(forURI: input)
            #expect(url?.scheme == "https", "\(input) produced \(String(describing: url?.scheme))")
        }
        #expect(SpotifyLink.home.scheme == "https")
    }

    /// Spotify used the owner-scoped spelling for years and still emits it in
    /// places. The user in the middle is not part of the web URL.
    @Test("The owner-scoped playlist URI drops the owner")
    func legacyPlaylistURI() {
        #expect(
            SpotifyLink.url(forURI: "spotify:user:sam:playlist:3cEYpjA9oz9GiPac4AsH4n")
                == URL(string: "https://open.spotify.com/playlist/3cEYpjA9oz9GiPac4AsH4n")
        )
    }

    /// A local file has no server-side object, so there is no page to open and
    /// nothing honest to return. Better no button than one that 404s.
    @Test("Anything Spotify does not host gets no link")
    func unhostedGetsNothing() {
        #expect(SpotifyLink.url(forURI: "spotify:local:Artist:Album:Track:210") == nil)
        #expect(SpotifyLink.url(forURI: "spotify:track:") == nil)
        #expect(SpotifyLink.url(forURI: "") == nil)
        #expect(SpotifyLink.url(forURI: "not a uri at all") == nil)
    }
}
