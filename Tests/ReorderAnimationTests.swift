import Foundation
import Testing

/// The policy behind the reorder, which is a decision rather than a layout
/// detail. The *number* in it is a measurement — see `docs/adr/0005` — and
/// these tests pin the rule, not the measurement.
@Suite("Reorder animation")
struct ReorderAnimationTests {

    @Test("A playlist at or under the limit animates")
    func shortPlaylistsAnimate() {
        #expect(ReorderAnimation.animates(rowCount: 1, reduceMotion: false))
        #expect(ReorderAnimation.animates(rowCount: 68, reduceMotion: false))
        #expect(ReorderAnimation.animates(rowCount: ReorderAnimation.rowLimit, reduceMotion: false))
    }

    @Test("Above it, the list snaps")
    func longPlaylistsSnap() {
        #expect(!ReorderAnimation.animates(rowCount: ReorderAnimation.rowLimit + 1, reduceMotion: false))
        #expect(!ReorderAnimation.animates(rowCount: 10_000, reduceMotion: false))
    }

    /// A setting, not a hint. A spring is precisely the motion it is turned on
    /// to avoid, so no playlist is short enough to override it.
    @Test("Reduced Motion snaps at every size")
    func reducedMotionAlwaysSnaps() {
        for count in [0, 1, 68, ReorderAnimation.rowLimit, 10_000] {
            #expect(!ReorderAnimation.animates(rowCount: count, reduceMotion: true), "\(count) rows")
        }
    }

    /// The whole demo catalogue animates, so every screenshot and every hands-on
    /// look at the app is of the animated path rather than the fallback.
    @Test("Every demo playlist is under the limit")
    func demoCatalogueAnimates() {
        for playlist in DemoCatalog.shared.playlists {
            #expect(
                ReorderAnimation.animates(rowCount: playlist.tracks.total, reduceMotion: false),
                "\(playlist.name)"
            )
        }
    }
}
