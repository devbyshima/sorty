import Foundation

/// The BPM range filter shown above the tracks.
public struct BPMFilter: Sendable, Hashable {
    public var minBPM: Int?
    public var maxBPM: Int?
    /// Also match tracks whose BPM *doubled* lands in range — a 70 BPM track and
    /// a 140 BPM track often feel like the same tempo on the floor, and tempo
    /// detectors routinely halve one or double the other.
    public var includeDoubled: Bool

    public init(minBPM: Int? = nil, maxBPM: Int? = nil, includeDoubled: Bool = true) {
        self.minBPM = minBPM
        self.maxBPM = maxBPM
        self.includeDoubled = includeDoubled
    }

    public var isActive: Bool { minBPM != nil || maxBPM != nil }

    static func inRange(_ value: Int, min: Int?, max: Int?) -> Bool {
        switch (min, max) {
        case (nil, nil): true
        case (nil, let hi?): value <= hi
        case (let lo?, nil): value >= lo
        case (let lo?, let hi?): value >= lo && value <= hi
        }
    }

    /// Rows with no BPM at all — episodes, or tracks the feature provider had
    /// nothing for — always pass, so filtering never silently drops them.
    public func accepts(_ row: TrackRow) -> Bool {
        guard isActive else { return true }
        guard let bpmValue = row.numericValue(for: .bpm) else { return true }
        let bpm = Int(bpmValue)
        if Self.inRange(bpm, min: minBPM, max: maxBPM) { return true }
        return includeDoubled && Self.inRange(bpm * 2, min: minBPM, max: maxBPM)
    }
}

public enum PlaylistSorter {
    /// Applies an Arrangement. Missing values always sink to the bottom,
    /// whichever direction is active, and ties keep their original playlist
    /// order so the result is stable and repeatable.
    public static func ordered(_ rows: [TrackRow], by arrangement: Arrangement) -> [TrackRow] {
        switch arrangement {
        case .attribute(let attribute, let direction) where attribute.isNumeric:
            ranked(rows, direction, key: { $0.numericValue(for: attribute) }, compare: compareNumbers)

        case .attribute(let attribute, let direction):
            ranked(rows, direction, key: { $0.textValue(for: attribute) },
                   compare: { $0.localizedStandardCompare($1) })

        case .artistSeparation:
            ranked(rows, .ascending, key: { $0.artistSeparationIndex.map(Double.init) },
                   compare: compareNumbers)

        case .shuffle(let seed):
            ranked(rows, .ascending, key: { shuffleKey(originalIndex: $0.originalIndex, seed: seed) },
                   compare: { $0 == $1 ? .orderedSame : ($0 < $1 ? .orderedAscending : .orderedDescending) })
        }
    }

    /// A track's place in a shuffle, derived from the seed rather than stored.
    ///
    /// Deliberately SplitMix64 and not `Hasher`/`hashValue`: those are seeded
    /// per process, so the "same" shuffle would come out differently on every
    /// launch and a screenshot of one could never be reproduced.
    static func shuffleKey(originalIndex: Int, seed: UInt64) -> UInt64 {
        func mix(_ value: UInt64) -> UInt64 {
            var z = value &+ 0x9E37_79B9_7F4A_7C15
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        return mix(seed ^ mix(UInt64(bitPattern: Int64(originalIndex))))
    }

    private static func compareNumbers(_ a: Double, _ b: Double) -> ComparisonResult {
        a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
    }

    private static func ranked<Value>(
        _ rows: [TrackRow],
        _ direction: Arrangement.Direction,
        key: (TrackRow) -> Value?,
        compare: (Value, Value) -> ComparisonResult
    ) -> [TrackRow] {
        let multiplier = direction.multiplier

        return rows.sorted { lhs, rhs in
            let comparison: Int

            switch (key(lhs), key(rhs)) {
            case (nil, nil): comparison = 0
            case (nil, _): return false   // nil sinks
            case (_, nil): return true
            case (let a?, let b?):
                switch compare(a, b) {
                case .orderedSame: comparison = 0
                case .orderedAscending: comparison = -1 * multiplier
                case .orderedDescending: comparison = 1 * multiplier
                }
            }

            // Ties keep their original playlist order, so arranging is stable
            // and repeatable rather than dependent on the sort algorithm.
            if comparison == 0 { return lhs.originalIndex < rhs.originalIndex }
            return comparison < 0
        }
    }

    /// Splits an arranged playlist into what the Arrangement could place and
    /// what it couldn't, each part in arrangement order.
    ///
    /// The unrankable ones already sank to the bottom — nil sinks in both
    /// directions — but they did it silently, showing a dash. Naming them is
    /// what turns a run of blank rows from "the app is broken" into "the
    /// provider had nothing for these".
    public static func partition(
        _ rows: [TrackRow], by arrangement: Arrangement
    ) -> (ranked: [TrackRow], unrankable: [TrackRow]) {
        let ordered = ordered(rows, by: arrangement)
        guard let attribute = arrangement.rankingAttribute else {
            // Artist separation and shuffle place every track by construction.
            return (ordered, [])
        }
        var ranked: [TrackRow] = []
        var unrankable: [TrackRow] = []
        for row in ordered {
            if row.canBeRanked(by: attribute) { ranked.append(row) } else { unrankable.append(row) }
        }
        return (ranked, unrankable)
    }

    /// Rows in the exact order and membership that a save-as-new would write.
    public static func arrange(_ rows: [TrackRow], by arrangement: Arrangement, filter: BPMFilter) -> [TrackRow] {
        ordered(rows, by: arrangement).filter { filter.accepts($0) }
    }

    /// Track/episode URIs for the current arrangement, ready to PUT to Spotify.
    public static func saveURIs(for rows: [TrackRow], by arrangement: Arrangement, filter: BPMFilter) -> [String] {
        arrange(rows, by: arrangement, filter: filter).compactMap(\.savableURI)
    }

}

// MARK: - Naming a saved playlist

public enum SaveNaming {
    public static func playlistName(original: String, arrangement: Arrangement) -> String {
        "\(original) ordered by \(arrangement.name)"
    }

    public static func playlistDescription(original: String?, arrangement: Arrangement) -> String {
        let prefix: String
        if let original, !original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, original != "null" {
            prefix = original.trimmingCharacters(in: .whitespacesAndNewlines) + " - "
        } else {
            prefix = ""
        }
        return "\(prefix)Sorted by \(arrangement.name) with Sortify"
    }
}
