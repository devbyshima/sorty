import Foundation

/// Everything a track row says, resolved once from the row and the applied
/// Arrangement.
///
/// This is not layout - it is the set of decisions about *what words appear*,
/// and every one of them is a rule: identity is never dropped, an Attribute the
/// row already shows is not printed twice, a missing measurement is absent
/// rather than zero, and VoiceOver gets one sentence instead of a reading of
/// every cell. Those belong where they can be tested.
public struct TrackRowText: Equatable, Sendable {
    /// 1-based position in the *current* arrangement, not the original order.
    /// Nil for a track the Arrangement couldn't place - numbering it would
    /// imply a rank it doesn't have.
    public let position: String?
    public let title: String
    /// Artist, or what the entry is when there isn't one.
    public let subtitle: String
    /// The active Arrangement's value, or nil when there is nothing worth
    /// showing - see `isAlreadyVisible`.
    public let value: String?
    /// The whole row as one spoken sentence.
    public let spoken: String

    public init(row: TrackRow, position: Int?, arrangement: Arrangement) {
        let title = row.playable.name
        let subtitle = Self.subtitle(for: row)

        self.position = position.map(String.init)
        self.title = title
        self.subtitle = subtitle

        let attribute = arrangement.rankingAttribute
        let shown = attribute.flatMap { attribute -> String? in
            guard !Self.isAlreadyVisible(attribute) else { return nil }
            let text = row.displayValue(for: attribute)
            return text.isEmpty ? nil : text
        }
        self.value = shown

        // A track the Arrangement couldn't place has no position to announce.
        let identity = "\(title) by \(subtitle)."
        var sentence = position.map { "\($0). \(identity)" } ?? identity
        if let attribute, !Self.isAlreadyVisible(attribute) {
            sentence += " \(attribute.name) \(shown ?? "unavailable")."
        }
        self.spoken = sentence
    }

    /// Title and artist are on every row already, and order is the row's own
    /// place in the list. Repeating one in the value slot says nothing the row
    /// does not, and makes VoiceOver say it twice in a sentence that is meant to
    /// be read quickly.
    ///
    /// `position` no longer appears on the row - the number column was removed
    /// so artwork could sit at the same margin as everything else - but it is
    /// still spoken, because rank in an ordered list is real information that a
    /// sighted reader gets from the sequence itself.
    static func isAlreadyVisible(_ attribute: Attribute) -> Bool {
        switch attribute {
        case .order, .title, .artist: true
        default: false
        }
    }

    /// Shared with the track detail sheet: opening a track must not rename it,
    /// and "Podcast episode" standing in for a missing artist is a decision
    /// rather than a fallback either surface should make for itself.
    static func subtitle(for row: TrackRow) -> String {
        if let artist = row.playable.primaryArtistName, !artist.isEmpty { return artist }
        return row.playable.isEpisode ? "Podcast episode" : "Unknown artist"
    }
}
