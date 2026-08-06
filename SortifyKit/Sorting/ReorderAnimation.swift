import Foundation

/// Whether applying an Arrangement should be watched or simply arrive.
///
/// Motion is the point of this app's defining action — without it, reordering a
/// playlist is indistinguishable from a table refresh. But a reorder that
/// stutters is worse than one that snaps, so there is a size above which the
/// list stops animating.
///
/// **The limit is a measurement**, and it is not the measurement the ticket
/// expected. See `docs/adr/0005` for the numbers, the device and the method.
///
/// A *single* reorder costs the same at 10,000 rows as at 100 — `LazyVStack`
/// lays out only what is visible, so the spring animates a dozen rows whatever
/// the playlist holds. Size showed up in one place only: several Arrangements
/// applied faster than anyone can tap. The limit is set from that.
public enum ReorderAnimation {
    /// Rows above which a reorder snaps.
    ///
    /// Measured on an iPhone 16 Pro (A18 Pro), not in the simulator: simulator
    /// frame timing is the Mac's and says nothing about a phone.
    ///
    /// Under a burst of six Arrangements in 480ms, late frames ran at 13% of
    /// the window at 100 rows, 15% at 1,000, and 24% at 5,000 — so the cost of
    /// a listener changing their mind quickly is flat up to about a thousand
    /// rows and then is not. That is where this sits.
    public static let rowLimit = 1_000

    /// Reduced Motion always snaps, at any size. It is a setting, not a hint,
    /// and a spring is exactly the kind of motion it is set to avoid.
    public static func animates(rowCount: Int, reduceMotion: Bool) -> Bool {
        guard !reduceMotion else { return false }
        return rowCount <= rowLimit
    }
}
