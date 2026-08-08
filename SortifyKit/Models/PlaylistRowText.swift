import Foundation

/// Everything a playlist row says.
///
/// The same shape as `TrackRowText`, and here for the same reason: what a row
/// *says* is a set of rules, and one of these rules is load-bearing. The badge
/// marking a playlist Sortify can't write to is derived from
/// `Playlist.isWritable(byUserID:)` - the very predicate that later decides
/// whether Overwrite is offered - so the list cannot promise something the next
/// screen withdraws.
public struct PlaylistRowText: Equatable, Sendable {
    /// Why a row carries a mark. Two conditions, not one: a playlist can be
    /// collaborative *and* writable (your own, opened up to friends), and it
    /// can be read-only without being collaborative (Discover Weekly).
    public enum Badge: String, Sendable, Hashable, Identifiable, CaseIterable {
        /// Other listeners can add to it, so its contents move under you.
        case collaborative
        /// Sortify can't write to it - which is why Overwrite won't be there
        /// when you open it. Said here rather than discovered there.
        case readOnly

        public var id: String { rawValue }

        public var label: String {
            switch self {
            case .collaborative: "Collaborative"
            case .readOnly: "Read-only"
            }
        }

        public var symbolName: String {
            switch self {
            case .collaborative: "person.2.fill"
            case .readOnly: "lock.fill"
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

    public init(playlist: Playlist, currentUserID: String?) {
        name = playlist.name
        trackCount = Self.trackCount(playlist.tracks.total)

        var badges: [Badge] = []
        if playlist.collaborative { badges.append(.collaborative) }
        if !playlist.isWritable(byUserID: currentUserID) { badges.append(.readOnly) }
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
