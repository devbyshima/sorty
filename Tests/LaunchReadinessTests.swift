import Foundation
import Testing

/// When the launch splash may stand down.
///
/// The whole reason `LaunchReadiness` is a value with `elapsed` as a parameter:
/// these are truth-table assertions rather than six seconds of waiting, and the
/// one rule that must never break - the splash cannot hang forever - is checked
/// here rather than hoped for in a simulator.
@Suite("Launch readiness")
struct LaunchReadinessTests {

    private let floor = LaunchReadiness.minimum
    private let ceiling = LaunchReadiness.timeout

    // MARK: - The floor

    /// Derived from `ConnectingView`'s own settle, not chosen: a splash torn off
    /// partway through a 750ms spring is a flash of a half-scaled mark rather
    /// than a screen anybody saw.
    @Test("Nothing releases before the floor, however ready it is")
    func theFloorHolds() {
        #expect(!LaunchReadiness.isSatisfied(.libraryReady, elapsed: .zero))
        #expect(!LaunchReadiness.isSatisfied(.libraryReady, elapsed: floor - .milliseconds(1)))
        #expect(LaunchReadiness.isSatisfied(.libraryReady, elapsed: floor))
    }

    /// The evidence the floor is a floor and not a brand moment: a brand moment
    /// would apply in both. `ConnectingView` skips its settle under Reduce
    /// Motion, so there is nothing left to protect.
    @Test("Reduce Motion removes the floor entirely")
    func reduceMotionHasNoFloor() {
        #expect(LaunchReadiness.isSatisfied(.libraryReady, elapsed: .zero, reduceMotion: true))
        #expect(!LaunchReadiness.isSatisfied(.connecting, elapsed: .zero, reduceMotion: true))
    }

    /// A first run has no account, nothing to restore and no playlists to wait
    /// for. Holding a mark over the way-in screen would be inventing a wait,
    /// which is the thing this design has twice written down that it will not
    /// do - so this is checked *before* the floor.
    @Test("Signed out releases immediately, floor and all")
    func signedOutNeverWaits() {
        #expect(LaunchReadiness.isSatisfied(.signedOut, elapsed: .zero))
        #expect(LaunchReadiness.isSatisfied(.signedOut, elapsed: .milliseconds(1)))
    }

    // MARK: - The ceiling

    /// **The rule whose absence would be a defect rather than a regression.**
    /// Whatever is stalled - a token refresh, `/me`, the first page - it does
    /// not get to hold the app hostage.
    @Test("The splash cannot outlast the ceiling in any state")
    func theCeilingAlwaysFires() {
        let everything: [LaunchReadiness.Progress] = [
            .connecting, .signedOut, .libraryIdle,
            .libraryLoading(loaded: 0), .libraryReady, .libraryFailed,
        ]
        for progress in everything {
            #expect(
                LaunchReadiness.isSatisfied(progress, elapsed: ceiling),
                "\(progress) held the splash past the ceiling"
            )
            #expect(LaunchReadiness.isSatisfied(progress, elapsed: ceiling + .seconds(30)))
        }
    }

    // MARK: - What counts as ready

    /// One real row is the least that makes the library worth uncovering. Not
    /// the page's `total`, which arrives on the same response and would be
    /// satisfied by one carrying no usable playlists at all.
    @Test("The first page having landed is one playlist, not a reported total")
    func oneRowIsEnough() {
        #expect(!LaunchReadiness.isSatisfied(.libraryLoading(loaded: 0), elapsed: floor))
        #expect(LaunchReadiness.isSatisfied(.libraryLoading(loaded: 1), elapsed: floor))
    }

    /// `completeSignIn` sets `stage = .ready` and *then* awaits
    /// `loadPlaylists()`, which sets `.loading` on its first line. Releasing in
    /// that window would uncover a grid that is empty for a reason nothing on
    /// screen can express.
    @Test("A ready session with an idle library is still covered")
    func theIdleWindowIsCovered() {
        #expect(!LaunchReadiness.isSatisfied(.libraryIdle, elapsed: floor))
        #expect(!LaunchReadiness.isSatisfied(.connecting, elapsed: floor))
    }

    /// The library draws an error with a Try Again on it, which is the one wait
    /// that *is* actionable. Holding a splash in front of the only state the
    /// listener can do something about is the worst of the four options.
    @Test("A failed library is uncovered rather than hidden")
    func failureReleases() {
        #expect(LaunchReadiness.isSatisfied(.libraryFailed, elapsed: floor))
    }
}

/// How many placeholders, and how they are kept from pulsing in unison.
@Suite("Skeleton plan")
struct SkeletonPlanTests {

    /// **Shapes even with nothing loaded**, which is not the obvious call: while
    /// the launch gate is up nobody sees them. It has a six-second ceiling it
    /// can hit with the first page still in flight, though, and that is the one
    /// moment ADR-0019 promises the library draws the shape of what is coming
    /// rather than an empty grid.
    @Test("An empty library still in flight draws the shape of what is coming")
    func shapesBeforeTheFirstPage() {
        #expect(SkeletonPlan.trailingCount(loaded: 0, total: 40, columns: 2) > 0)
        #expect(SkeletonPlan.trailingCount(loaded: 0, total: nil, columns: 2) > 0)
    }

    /// And none once every page has landed - the grid is the library at that
    /// point, and a trailing shape would promise a row that is not coming.
    @Test("No trailing placeholders once the library is complete")
    func nothingWhenComplete() {
        #expect(SkeletonPlan.trailingCount(loaded: 40, total: 40, columns: 2) == 0)
        #expect(SkeletonPlan.trailingCount(loaded: 41, total: 40, columns: 2) == 0)
    }

    /// Never more than are actually coming. Three outstanding playlists must not
    /// draw twelve shapes and then delete nine.
    @Test("Never more placeholders than there are playlists still to come")
    func neverOverPromises() {
        #expect(SkeletonPlan.trailingCount(loaded: 37, total: 40, columns: 2) <= 3)
        #expect(SkeletonPlan.trailingCount(loaded: 39, total: 40, columns: 3) <= 1)
    }

    /// Bounded, because `total` can be four hundred and nobody scrolls a
    /// placeholder.
    @Test("A huge library still draws a bounded number of shapes")
    func capped() {
        #expect(SkeletonPlan.trailingCount(loaded: 50, total: 4000, columns: 2) <= 12)
    }

    /// Nil `total` is Spotify not having said yet, which is exactly when a
    /// modest number of shapes is the honest answer.
    @Test("An unreported total still draws something")
    func unknownTotal() {
        #expect(SkeletonPlan.trailingCount(loaded: 3, total: nil, columns: 2) > 0)
        #expect(SkeletonPlan.trailingCount(loaded: 3, total: nil, columns: 2) <= 12)
    }

    /// A nine-track playlist showing twelve skeletons and then shrinking is the
    /// reflow this whole exercise exists to prevent.
    @Test("Track placeholders match the count Spotify reported")
    func trackCountFollowsThePlaylist() {
        #expect(SkeletonPlan.trackCount(expected: 9) == 9)
        #expect(SkeletonPlan.trackCount(expected: 500) == 12)
        #expect(SkeletonPlan.trackCount(expected: 0) == 1)
        // No count is every playlist the listener does not own, since February
        // 2026. A screenful is the only honest answer there.
        #expect(SkeletonPlan.trackCount(expected: nil) == 12)
    }

    /// A screen of twelve pulsing in unison reads as an error light rather than
    /// as waiting, so no two adjacent rows may share a phase.
    @Test("Adjacent placeholders are never in phase")
    func phasesAreSpread() {
        let phases = (0..<24).map { SkeletonPlan.phase(at: $0) }
        for (index, phase) in phases.enumerated() {
            #expect(phase >= 0 && phase < 4.5, "phase \(index) fell outside one cycle")
            if index > 0 {
                #expect(abs(phase - phases[index - 1]) > 0.2, "rows \(index - 1) and \(index) breathe together")
            }
        }
        // Stable: the same index is the same phase, every time, or placeholders
        // would reshuffle on every view update.
        #expect(SkeletonPlan.phase(at: 7) == SkeletonPlan.phase(at: 7))
    }
}
