import Foundation

/// A hole in a screen, and what to say about it.
///
/// The words are the design here, so they live in SortifyKit alongside
/// `TrackRowText` and `PlaylistRowText` rather than being typed into a view.
/// Three things distinguish these from an error: an empty state is a normal
/// outcome, it never blames the app, and where a way out exists it names the
/// way out rather than offering "Try Again".
public enum EmptyState: Equatable, Sendable {
    /// No account yet. Distinct from `noPlaylists`, which is a connected
    /// account with an empty library - the remedy is completely different and
    /// telling someone their playlists will "show up here" when nothing is
    /// connected is a lie of omission.
    case notConnected
    /// A search or category that matches none of the playlists the user has.
    case noPlaylistsMatch(hasSearch: Bool)
    /// A connected account with no playlists whatsoever, which is a different
    /// situation from a filter matching nothing and must not borrow its words.
    case noPlaylists
    /// A playlist Spotify returned with nothing playable in it.
    case playlistEmpty
    /// The tempo filter is narrow enough to hide every track. Previously this
    /// surfaced only as a save *failure*, which told the user about it at the
    /// last possible moment.
    case filterHidesEverything(total: Int)

    public var title: String {
        switch self {
        case .notConnected:
            "Not connected"
        case .noPlaylistsMatch(let hasSearch):
            hasSearch ? "No matches" : "Nothing in this category"
        case .noPlaylists:
            "No playlists yet"
        case .playlistEmpty:
            "Nothing to arrange"
        case .filterHidesEverything:
            "Every track is filtered out"
        }
    }

    public var message: String {
        switch self {
        case .notConnected:
            "Connect a Spotify account and your playlists will be here."
        case .noPlaylistsMatch(let hasSearch):
            hasSearch
                ? "Nothing in your library matches what you typed."
                : "You have playlists, but none of them are in this category."
        case .noPlaylists:
            "When you make a playlist on Spotify it will show up here."
        case .playlistEmpty:
            "This playlist has no playable tracks, so there is nothing to put in order."
        case .filterHidesEverything(let total):
            "The tempo range you set hides all \(total) tracks. Widen it or clear it to see them again."
        }
    }

    public var symbolName: String {
        switch self {
        case .notConnected: "link"
        case .noPlaylistsMatch: "magnifyingglass"
        case .noPlaylists: "music.note.list"
        case .playlistEmpty: "music.note.list"
        case .filterHidesEverything: "line.3.horizontal.decrease.circle"
        }
    }

    /// The way out, where there is one. Nil means the state is simply a fact
    /// about the user's library and no button can change it.
    public var actionTitle: String? {
        switch self {
        case .notConnected:
            "Connect Spotify"
        case .noPlaylistsMatch(let hasSearch):
            hasSearch ? "Clear search" : "Show all playlists"
        case .noPlaylists:
            nil
        case .playlistEmpty:
            nil
        case .filterHidesEverything:
            "Clear the filter"
        }
    }

    /// One sentence for VoiceOver, so an empty state is a single stop rather
    /// than a heading, a paragraph and a button read as three unrelated things.
    public var spoken: String {
        [title, message].joined(separator: ". ")
    }
}
