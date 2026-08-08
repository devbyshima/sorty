import Foundation

/// Everything the playlist screen says beneath the name.
///
/// Lifted out of `TrackListView`, where it had grown into one computed `String`
/// making four rules at once: whose playlist this is, how much is in it, whether
/// Spotify said how much, and whether a filter is hiding some of it. Those are
/// decisions about what words appear, and they belong where they can be tested,
/// the way `PlaylistRowText` and `TrackRowText` already are.
public struct PlaylistHeaderText: Equatable, Sendable {
    /// Who Spotify says owns this, or nil where it named nobody.
    ///
    /// Its own value rather than part of the line below, because the owner now
    /// has a line of their own with an avatar beside it.
    public let owner: String?

    /// What the avatar draws when there is no picture to draw, which is almost
    /// always.
    ///
    /// `PlaylistOwner` carries an id and a display name and no image at all, so
    /// the only listener whose face this app has is the signed-in one, from
    /// `/me`. Getting anyone else's would mean `GET /users/{id}` for every
    /// distinct owner in a library, and ADR-0008 is the record of how little a
    /// Development Mode app has to spend. Initials are what Spotify itself
    /// falls back to, so this is the shape people already read as an avatar.
    public let ownerInitials: String

    /// How much is in the playlist: "68 tracks", "12 of 68 tracks" while a
    /// filter is on, or `PlaylistRowText.hiddenTrackCount` where Spotify sent no
    /// count at all (ADR-0008).
    public let tracks: String

    /// How long the tracks on screen run, or nil before any have loaded.
    ///
    /// Spotify's playlist listing carries no total duration, only a count, so
    /// this cannot be known until the items are in hand. That is the same reason
    /// the count changes source mid-load, and it is why this is optional rather
    /// than zero: "0m" under a playlist that is still arriving would be a
    /// number the app does not have.
    public let duration: String?

    /// The line beneath the owner, as one string.
    public let detail: String

    /// The header's metadata as one sentence, for VoiceOver.
    public let spoken: String

    /// - Parameters:
    ///   - playlist: what the library listing knew before anything was opened.
    ///   - loadedCount: how many rows have actually arrived. 0 before a load.
    ///   - visible: the rows on screen, which a tempo filter may have narrowed.
    ///     The running time is of these, not of the whole playlist: a filtered
    ///     list says "12 of 68 tracks", and a duration measuring the 68 next to
    ///     a count measuring the 12 would describe two different playlists on
    ///     one line.
    ///   - isFiltered: whether that narrowing is in force.
    public init(playlist: Playlist, loadedCount: Int, visible: [TrackRow], isFiltered: Bool) {
        let name = playlist.owner.displayName ?? playlist.owner.id
        let owner = name.isEmpty ? nil : name
        self.owner = owner
        self.ownerInitials = Self.initials(of: owner)

        // Nothing loaded and nothing reported. A count Spotify withheld is not a
        // count of zero.
        let tracks: String
        if !playlist.trackCountIsKnown, loadedCount == 0 {
            tracks = PlaylistRowText.hiddenTrackCount
        } else {
            let total = loadedCount == 0 ? playlist.tracks.total : loadedCount
            if isFiltered {
                tracks = "\(visible.count) of \(total) tracks"
            } else {
                tracks = total == 1 ? "1 track" : "\(total) tracks"
            }
        }
        let duration = Self.runningTime(of: visible)
        let detail = [tracks, duration].compactMap(\.self).joined(separator: " · ")

        self.tracks = tracks
        self.duration = duration
        self.detail = detail
        self.spoken = owner.map { "\($0). \(detail)" } ?? detail
    }

    /// Up to two letters, from the first two words of a display name.
    ///
    /// A Spotify account name can be an email address or a user id where the
    /// listener never set one, so this takes what it can and refuses to invent:
    /// nothing usable produces a single question mark rather than an empty
    /// circle, which reads as a missing image rather than as a broken one.
    static func initials(of owner: String?) -> String {
        guard let owner else { return "?" }
        let words = owner
            .split(whereSeparator: { $0 == " " || $0 == "." || $0 == "_" })
            .prefix(2)
        let letters = words.compactMap(\.first).map(String.init)
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }

    /// Hours and minutes, the way a playlist's length is read.
    ///
    /// Deliberately not `TrackRow.formatDuration`, which produces `m:ss` for one
    /// track. A playlist rendered that way reads "237:14", which is a number
    /// nobody converts in their head.
    ///
    /// The feature provider's length wins over the track's own, which is the
    /// precedence `TrackRow.numericValue(for: .length)` already uses. Both are
    /// the same measurement, either can be missing, and a total that disagreed
    /// with the sum of the lengths shown on the rows would be worse than either.
    static func runningTime(of rows: [TrackRow]) -> String? {
        let ms = rows.reduce(0) { total, row in
            total + (row.features?.durationMS ?? row.playable.durationMS ?? 0)
        }
        guard ms > 0 else { return nil }

        let minutes = ms / 60_000
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        if minutes >= 1 { return "\(minutes)m" }
        // A playlist this short is a rounding artefact or one very short clip,
        // and "0m" would read as a missing measurement rather than a tiny one.
        return "under a minute"
    }
}
