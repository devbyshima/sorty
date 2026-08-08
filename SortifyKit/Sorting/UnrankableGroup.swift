import Foundation

/// Why an Arrangement couldn't place a track.
///
/// The distinction is the point: "a podcast episode has no tempo" is a fact
/// about what the track *is* and will never change, while "the audio-feature
/// source had no match" is a gap that might close. A listener who can't tell
/// them apart doesn't know whether to expect it to improve.
public enum UnrankableReason: Sendable, Hashable {
    /// Not music, or not something Sortify reads for an episode.
    case episode
    /// Music the audio-feature source had nothing for.
    case notMeasured
    /// Metadata Spotify didn't supply - a release date it doesn't know.
    case missing

    public init(for row: TrackRow, attribute: Attribute) {
        if row.playable.isEpisode {
            self = .episode
        } else if attribute.isAudioFeature {
            self = .notMeasured
        } else {
            self = .missing
        }
    }

    /// The mark on the group's header. Here rather than in the view for the
    /// same reason the copy is: it is a decision per reason, and a reason added
    /// later should fail to compile until someone chooses one.
    public var symbolName: String {
        switch self {
        case .episode: "mic"
        case .notMeasured: "waveform.slash"
        case .missing: "questionmark.circle"
        }
    }
}

/// Tracks the active Arrangement couldn't rank, gathered under a header that
/// says how many there are and why.
///
/// They are grouped *by reason* rather than lumped together, because one header
/// covering both kinds could only be vague about which tracks were which.
public struct UnrankableGroup: Identifiable, Sendable, Hashable {
    public let reason: UnrankableReason
    public let rows: [TrackRow]

    public var id: UnrankableReason { reason }
    public var count: Int { rows.count }

    /// States the count, so the header can never disagree with its contents.
    public let title: String
    /// Why these are here, in a sentence.
    public let detail: String

    /// Groups in the order they should appear. Reasons a listener might act on
    /// come first; episodes last, because an episode having no tempo is
    /// expected rather than informative.
    ///
    /// `providerNote` is the audio-feature source's own explanation, which used
    /// to be shown only when *every* track failed. It goes to the group it
    /// actually explains.
    public static func groups(
        for rows: [TrackRow], attribute: Attribute, providerNote: String?
    ) -> [UnrankableGroup] {
        let byReason = Dictionary(grouping: rows) { UnrankableReason(for: $0, attribute: attribute) }

        let order: [UnrankableReason] = [.notMeasured, .missing, .episode]
        return order.compactMap { reason -> UnrankableGroup? in
            guard let rows = byReason[reason], !rows.isEmpty else { return nil }
            return UnrankableGroup(
                reason: reason,
                rows: rows,
                title: title(reason: reason, count: rows.count, attribute: attribute),
                detail: detail(reason: reason, attribute: attribute, providerNote: providerNote)
            )
        }
    }

    private static func title(reason: UnrankableReason, count: Int, attribute: Attribute) -> String {
        switch reason {
        case .episode:
            count == 1 ? "1 podcast episode" : "\(count) podcast episodes"
        case .notMeasured, .missing:
            "\(count) \(count == 1 ? "track" : "tracks") without \(attribute.name)"
        }
    }

    private static func detail(
        reason: UnrankableReason, attribute: Attribute, providerNote: String?
    ) -> String {
        let kept = "They stay in the playlist and are saved with it."
        switch reason {
        case .episode where attribute.isAudioFeature:
            // True only of the audio features. An episode really has no tempo.
            return "\(attribute.name) is measured from music, and a podcast episode isn't music. \(kept)"
        case .episode:
            // A Spotify episode may well have a release date or a popularity -
            // Sortify just doesn't read them, and saying "an episode isn't
            // music" would be the wrong reason.
            return "Sortify doesn't read \(attribute.name) for podcast episodes. \(kept)"
        case .notMeasured:
            // The provider's own words when it has any, but the reassurance is
            // appended either way: a listener looking at tracks the app
            // couldn't place needs to know they aren't about to be dropped.
            let why = providerNote
                ?? "The audio-feature source had no \(attribute.name) for these. Coverage is thinnest on recent releases."
            return "\(why) \(kept)"
        case .missing:
            return "Spotify didn't supply \(attribute.name) for these. \(kept)"
        }
    }
}
