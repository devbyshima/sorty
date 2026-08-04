import Foundation

/// The BPM range filter shown above the table.
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

/// Everything that defines "what the user is looking at", so the app can tell
/// whether the current arrangement differs from the last one saved.
public struct SortState: Sendable, Hashable {
    public var column: SortColumn
    public var direction: SortDirection
    public var filter: BPMFilter

    public init(column: SortColumn = .order, direction: SortDirection = .ascending, filter: BPMFilter = BPMFilter()) {
        self.column = column
        self.direction = direction
        self.filter = filter
    }
}

public enum PlaylistSorter {
    /// Sorts rows by a column. Missing values always sink to the bottom,
    /// whichever direction is active.
    public static func sorted(_ rows: [TrackRow], by column: SortColumn, direction: SortDirection) -> [TrackRow] {
        let multiplier = direction.multiplier

        return rows.sorted { lhs, rhs in
            let comparison: Int

            if column.isNumeric {
                let a = lhs.numericValue(for: column)
                let b = rhs.numericValue(for: column)
                switch (a, b) {
                case (nil, nil): comparison = 0
                case (nil, _): return false   // nil sinks
                case (_, nil): return true
                case (let a?, let b?):
                    if a == b { comparison = 0 } else { comparison = (a < b ? -1 : 1) * multiplier }
                }
            } else {
                let a = lhs.textValue(for: column)
                let b = rhs.textValue(for: column)
                switch (a, b) {
                case (nil, nil): comparison = 0
                case (nil, _): return false
                case (_, nil): return true
                case (let a?, let b?):
                    let result = a.localizedStandardCompare(b)
                    comparison = result == .orderedSame ? 0 : (result == .orderedAscending ? -1 : 1) * multiplier
                }
            }

            // Ties keep their original playlist order, so sorting is stable and
            // repeatable rather than dependent on the sort algorithm.
            if comparison == 0 { return lhs.originalIndex < rhs.originalIndex }
            return comparison < 0
        }
    }

    /// Rows in the exact order and membership that a save would write.
    public static func arrange(_ rows: [TrackRow], state: SortState) -> [TrackRow] {
        sorted(rows, by: state.column, direction: state.direction)
            .filter { state.filter.accepts($0) }
    }

    /// Track/episode URIs for the current arrangement, ready to PUT to Spotify.
    public static func saveURIs(for rows: [TrackRow], state: SortState) -> [String] {
        arrange(rows, state: state).compactMap(\.savableURI)
    }

    /// Fresh random values for every row — called each time the Random column is
    /// selected, so tapping it repeatedly reshuffles.
    public static func reroll(_ rows: inout [TrackRow]) {
        for index in rows.indices {
            rows[index].randomValue = Int.random(in: 0..<10_000)
        }
    }
}

// MARK: - Naming a saved playlist

public enum SaveNaming {
    /// "increasing BPM", "decreasing Energy", or just "A.Sep" / "Rnd" for the
    /// two columns where direction is meaningless.
    public static func sortName(column: SortColumn, direction: SortDirection) -> String {
        guard column.directionMatters else { return column.label }
        return "\(direction.savedNameWord) \(column.label)"
    }

    public static func playlistName(original: String, column: SortColumn, direction: SortDirection) -> String {
        "\(original) ordered by \(sortName(column: column, direction: direction))"
    }

    public static func playlistDescription(
        original: String?,
        column: SortColumn,
        direction: SortDirection
    ) -> String {
        let prefix: String
        if let original, !original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, original != "null" {
            prefix = original.trimmingCharacters(in: .whitespacesAndNewlines) + " - "
        } else {
            prefix = ""
        }
        return "\(prefix)Sorted by \(sortName(column: column, direction: direction)) with Sortify"
    }
}
