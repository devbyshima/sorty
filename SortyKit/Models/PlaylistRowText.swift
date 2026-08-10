import Foundation

/// Everything a playlist row says.
///
/// The same shape as `TrackRowText`, and here for the same reason: what a row
/// *says* is a set of rules, and one of these rules is load-bearing. The badge
/// marking a playlist Sorty can't write to is derived from
/// `Playlist.isWritable(byUserID:)` - the very predicate that later decides
/// whether Overwrite is offered - so the list cannot promise something the next
/// screen withdraws.
public struct PlaylistRowText: Equatable, Sendable {
    /// Why a row carries a mark.
    ///
    /// Both marks are about what the *next* screen will do, and the more final
    /// one wins: telling someone Overwrite will be missing from a screen they
    /// can never reach is noise in front of the fact that matters.
    ///
    /// There was a third, `collaborative`, until ADR-0017. It answered "can
    /// other people change this under me?", which is a true thing about a
    /// playlist that nothing in Sorty acts on - unlike these two, each of which
    /// predicts a control the next screen will or will not have.
    public enum Badge: String, Sendable, Hashable, Identifiable, CaseIterable {
        /// Sorty can't write to it - which is why Overwrite won't be there
        /// when you open it. Said here rather than discovered there.
        case readOnly
        /// Spotify won't send its tracks at all, so the row leads nowhere.
        /// Said here for the same reason as `readOnly` and more urgently: a
        /// listener who taps this one gets a screen with no playlist in it.
        case cantOpen

        public var id: String { rawValue }

        public var label: String {
            switch self {
            case .readOnly: "Read-only"
            case .cantOpen: "Can't open"
            }
        }

        public var symbolName: String {
            switch self {
            case .readOnly: "lock.fill"
            case .cantOpen: "lock.slash.fill"
            }
        }
    }

    public let name: String
    /// "68 tracks", and "1 track" where it must be.
    public let trackCount: String
    /// In the order they appear. Empty for a playlist that is simply yours.
    public let badges: [Badge]
    /// The whole row as one spoken sentence, so VoiceOver reads a playlist
    /// rather than a thumbnail, a name, a number and two icons.
    public let spoken: String

    /// What to say where Spotify sent no count. Shared with the playlist
    /// screen's own subtitle, which faces the same gap and must not fill it with
    /// a different sentence.
    public static let hiddenTrackCount = "Track count hidden"

    public init(playlist: Playlist, currentUserID: String?) {
        name = playlist.name
        let canOpen = playlist.contentsAreReadable(byUserID: currentUserID)
        // A count Spotify withheld is not a count of zero, and "0 tracks" under
        // a playlist that plainly has some is the app inventing a fact.
        trackCount = playlist.trackCountIsKnown
            ? Self.trackCount(playlist.tracks.total)
            : Self.hiddenTrackCount

        var badges: [Badge] = []
        // Read-only is beside the point on a playlist that never opens: it
        // answers "why is Overwrite missing" for a screen the listener will
        // never reach. One mark, the one that decides whether tapping is worth
        // it.
        if !canOpen {
            badges.append(.cantOpen)
        } else if !playlist.isWritable(byUserID: currentUserID) {
            badges.append(.readOnly)
        }
        self.badges = badges

        let marks = badges.map(\.label).joined(separator: ", ")
        spoken = marks.isEmpty
            ? "\(name), \(trackCount)."
            : "\(name), \(trackCount), \(marks)."
    }

    private static func trackCount(_ total: Int) -> String {
        total == 1 ? "1 track" : "\(total) tracks"
    }
}
