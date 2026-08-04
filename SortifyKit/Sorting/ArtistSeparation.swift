import Foundation

/// Spreads each artist's tracks as evenly as possible across the playlist, so
/// you never hear the same artist twice in a row.
///
/// Greedy: at every position, pick the remaining track whose artist is furthest
/// *behind* its fair share of the playlist so far. An artist holding 3 of 12
/// tracks wants to occupy 25% of every prefix, so it gets picked whenever its
/// running share dips below that.
///
/// This is a direct port of the reference implementation, with one fix: the
/// original skips tracks that have no artist (podcast episodes), then crashes
/// when it eventually has to place one. Here artist-less entries share a single
/// bucket and get distributed like any other "artist".
public enum ArtistSeparation {
    /// Assigns `artistSeparationIndex` to every row. Row order is untouched —
    /// only the index is written, so the caller decides when to actually sort.
    public static func assignIndices(to rows: inout [TrackRow]) {
        let total = rows.count
        guard total > 0 else { return }

        func artistKey(_ row: TrackRow) -> String {
            row.playable.primaryArtistName ?? ""
        }

        var totalByArtist: [String: Int] = [:]
        for row in rows {
            totalByArtist[artistKey(row), default: 0] += 1
        }

        var placedByArtist: [String: Int] = [:]
        var placedCount = 0

        // Indices into `rows` that still need a position.
        var remaining = Array(rows.indices)

        while !remaining.isEmpty {
            var bestDelta = Double.infinity
            var bestSlot = 0

            for (slot, rowIndex) in remaining.enumerated() {
                let key = artistKey(rows[rowIndex])
                let desiredShare = Double(totalByArtist[key] ?? 0) / Double(total)
                let shareIfPlacedNext = Double((placedByArtist[key] ?? 0) + 1) / Double(placedCount + 1)
                let delta = abs(shareIfPlacedNext - desiredShare)
                if delta < bestDelta {
                    bestDelta = delta
                    bestSlot = slot
                }
            }

            let chosen = remaining.remove(at: bestSlot)
            rows[chosen].artistSeparationIndex = placedCount
            placedByArtist[artistKey(rows[chosen]), default: 0] += 1
            placedCount += 1
        }
    }
}
