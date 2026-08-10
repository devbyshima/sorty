import Foundation

/// A line the library carries when it is not the whole library.
///
/// The words live here for the reason `EmptyState` and `PlaylistRowText` do:
/// they are the design, and they are the only part of this that can be
/// asserted. A notice nobody can test is a notice that quietly becomes wrong.
///
/// This file used to be `ReconnectNotice`, whose one sentence offered a
/// reconnect to a listener whose token predated `playlist-read-collaborative`
/// (ADR-0017 removed it along with the rest of the collaborative surfaces). What
/// replaces it is the opposite kind of notice: the old one named a fault with a
/// fix, and this one names a rule with none.
public enum LibraryNotice {

    /// Playlists Spotify listed and would not name.
    ///
    /// Spotify's listing can carry entries it declines to describe - a `null`
    /// where a playlist object should be. A null has no id, no name and no
    /// cover, so there is no row to draw for it; it was compacted away, which
    /// made this a deletion the listener could not see and could not ask about.
    /// Their library simply held fewer playlists in Sorty than in Spotify, which
    /// is the exact shape of "Spotify's own playlists aren't being recognised".
    ///
    /// It can still be counted, and the count is the whole difference between a
    /// library that is quietly four playlists short and one that says so.
    ///
    /// Nil below one, because a footer explaining an absence of nothing is worse
    /// than silence. **No action, deliberately**: there is no permission to
    /// grant and no button that would work, and offering one would be the app
    /// pretending it had a way out. ADR-0018.
    public static func withheldFromListing(count: Int) -> String? {
        guard count > 0 else { return nil }
        let playlists = count == 1 ? "1 playlist" : "\(count) playlists"
        let pronoun = count == 1 ? "it" : "them"
        return """
            Spotify listed \(playlists) without naming \(pronoun), so there is \
            nothing here to draw. It withholds its own that way - Discover \
            Weekly, the Daily Mixes, the editorial and chart lists - from every \
            app at Sorty's quota, and no permission you could grant changes it.
            """
    }
}
