import Foundation

/// How many placeholders to draw, and how to keep them from pulsing as one
/// organism.
///
/// The arithmetic half of ADR-0019, here rather than in the view for the reason
/// `LaunchReadiness` is: a count that is wrong by one is a reflow at the moment
/// the real rows arrive, and that is a thing to assert rather than to eyeball at
/// eleven Dynamic Type sizes.
public enum SkeletonPlan {

    /// Placeholders drawn *after* the playlists already in hand, while more
    /// pages are still coming.
    ///
    /// Trailing rather than a screenful, and this is the whole of what ADR-0015
    /// still gets right about the library: the grid genuinely does fill, batch
    /// by batch, so the part that has arrived needs no explaining. What 0015
    /// never covered is the part that has not - a two-up grid showing three of
    /// forty-seven playlists is not a library filling, it is a library that
    /// looks finished and is wrong.
    ///
    /// Bounded because `total` can be four hundred and nobody scrolls a
    /// placeholder: enough to fill the fold under the last real row and stop.
    /// Nil `total` means Spotify has not said yet, which is exactly when a
    /// modest number of shapes is the honest answer.
    ///
    /// **Zero loaded still draws them**, which is not the obvious call. While
    /// the launch gate is up nobody sees these, so it looks like a layout pass
    /// spent on nothing - but the gate has a six-second ceiling it can hit with
    /// the first page still in flight, and that is the one moment ADR-0019
    /// promises the library will draw the shape of what is coming rather than an
    /// empty grid. Returning zero here would have made the ceiling uncover
    /// exactly the emptiness it exists to avoid.
    public static func trailingCount(loaded: Int, total: Int?, columns: Int, cap: Int = 12) -> Int {
        guard loaded >= 0 else { return 0 }
        guard let total else { return min(max(columns * 2, cap / 2), cap) }
        let remaining = max(0, total - loaded)
        guard remaining > 0 else { return 0 }
        // Round up to a whole row so the grid never ends on a ragged edge that
        // then squares itself when the real tiles land.
        let rounded = Int((Double(min(remaining, cap)) / Double(max(columns, 1))).rounded(.up))
            * max(columns, 1)
        return min(rounded, min(remaining, cap))
    }

    /// Placeholder rows for a track list that has nothing at all yet.
    ///
    /// `TrackListModel` assigns `rows` once, after every page has landed, so
    /// unlike the library there is never a partial list to trail: the skeleton
    /// is the only content the screen can have, and it is replaced whole.
    ///
    /// The playlist's own count where Spotify sent one - a nine-track playlist
    /// showing twelve skeletons and then shrinking is the reflow this exists to
    /// prevent - and a screenful where it did not.
    public static func trackCount(expected: Int?, cap: Int = 12) -> Int {
        guard let expected else { return cap }
        return max(1, min(expected, cap))
    }

    /// One full sweep of the placeholder shimmer, in seconds.
    ///
    /// **Here rather than beside the view, because it is a number two files have
    /// to agree on and one of them is Metal.** `CoverShimmer.cycle` reads this,
    /// and `coverShimmer`'s own `cycle` constant in `Shaders.metal` must equal
    /// it - a shader cannot import Swift, so that pair is kept by hand and this
    /// is the value it is kept against. Putting it in SortyKit is also what lets
    /// `phase(at:)` be tested at the period the app actually runs.
    ///
    /// 2.2s. A sweep has to be quicker than the nine-second breath it replaced
    /// or it stops reading as one gesture, and slower than the ~1.2s web idiom
    /// or it reads as a loading bar. ADR-0020.
    public static let period: Double = 2.2

    /// A stable per-row offset into the sweep, so a screen of twelve does not
    /// shimmer in unison - which reads as an error light rather than as waiting,
    /// and which is also the property that stops a band travelling across a
    /// whole list from reading as one measurement of progress.
    ///
    /// The same property `CoverImage.shimmerPhase(for:)` takes from a URL hash,
    /// taken from the index instead, because a placeholder has no URL to hash.
    /// The step is irrational so adjacent rows are never in phase and the
    /// pattern never repeats down a list of any length.
    public static func phase(at index: Int, period: Double = SkeletonPlan.period) -> Double {
        let golden = 0.6180339887498949
        return (Double(index) * golden).truncatingRemainder(dividingBy: 1) * period
    }
}
