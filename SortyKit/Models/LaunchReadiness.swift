import Foundation

/// Whether the launch splash may stand down.
///
/// **A value, not a view model, and in SortyKit on purpose.** Every rule below
/// is a decision about when an app is ready to be looked at, and the one thing
/// that must never happen - the splash hanging forever because a request
/// stalled - is exactly the kind of thing that is unfalsifiable inside a view
/// and trivial to pin down as a truth table.
///
/// There is no clock here. `elapsed` is a parameter, so a test can be at second
/// nine without waiting nine seconds, and the timeout is a line anyone can read
/// rather than a race anyone has to reproduce.
public enum LaunchReadiness {

    /// What the app has got to, reduced to the only distinctions the gate cares
    /// about.
    ///
    /// Its own type rather than `SessionModel.Stage` plus `PlaylistLoad`,
    /// because those carry a failure string and a page total that no rule here
    /// reads, and because `SessionModel` is main-actor-isolated while this is
    /// deliberately not isolated to anything.
    public enum Progress: Equatable, Sendable {
        /// `restore()` or `completeSignIn()` is still running. There is no
        /// library behind the splash yet - not an empty one, none.
        case connecting
        /// No account. The way in.
        case signedOut
        /// Connected, and `loadPlaylists()` has not set a phase yet.
        case libraryIdle
        /// Connected, with this many playlists actually in hand.
        case libraryLoading(loaded: Int)
        /// Every page landed.
        case libraryReady
        /// The library will draw an error with a Try Again on it.
        case libraryFailed
    }

    /// The floor, and it is derived rather than chosen.
    ///
    /// `ConnectingView` settles its mark with
    /// `.spring(response: 0.75, dampingFraction: 0.58)`. A splash torn off
    /// 120ms into that is not a screen anybody saw - it is a flash of a
    /// half-scaled mark on the way to somewhere else. This is the length of the
    /// thing already on screen, not a hold for its own sake, which is the
    /// difference between it and the timed brand card the Human Interface
    /// Guidelines rule out and `ConnectingView`'s own doc comment promises not
    /// to be.
    ///
    /// **Zero under Reduce Motion**, because `ConnectingView` skips the settle
    /// entirely there and there is nothing left to protect. That branch is the
    /// evidence this is a floor rather than a brand moment: a brand moment would
    /// apply in both. ADR-0019.
    public static let minimum: Duration = .milliseconds(700)

    /// The ceiling. **The splash can never outlast this, in any state.**
    ///
    /// Roughly two round trips on a bad connection, and well past the p99 of one
    /// `GET /me/playlists?limit=50`. What happens after it is what makes it safe
    /// to be this short: the app releases into a library that now draws the
    /// shape of what is coming instead of an empty grid. The timeout and the
    /// skeletons are one decision - without the skeletons this number would have
    /// to be a guess about how long is too long to look at nothing, and with
    /// them it is only "stop covering the app".
    public static let timeout: Duration = .seconds(6)

    /// - Parameters:
    ///   - elapsed: since the first frame, not since `restore()`. The splash is
    ///     what the app opens on, so on the path this exists for those are the
    ///     same instant, and the earlier of the two is the safer to time from.
    public static func isSatisfied(
        _ progress: Progress,
        elapsed: Duration,
        reduceMotion: Bool = false,
        minimum: Duration = minimum,
        timeout: Duration = timeout
    ) -> Bool {
        // First, and before the floor. A first run has no account, nothing to
        // restore and no playlists to wait for: `restore()` reads the Keychain
        // and lands here without touching the network (ADR-0007). Holding a mark
        // over the way-in screen for 700ms would be inventing a wait, which is
        // the one thing this whole design has twice written down that it will
        // not do.
        if progress == .signedOut { return true }

        // Second, and before everything that could say no. Whatever is stalled -
        // a token refresh, `/me`, the first page - it does not get to hold the
        // app hostage. This is the only rule in this file whose absence would be
        // a defect rather than a regression.
        if elapsed >= timeout { return true }

        if elapsed < (reduceMotion ? .zero : minimum) { return false }

        switch progress {
        case .signedOut:
            // Handled above; here so the switch stays total and the next case
            // added has to think about this one.
            return true

        case .connecting:
            return false

        case .libraryIdle:
            // A genuine window rather than a theoretical one: `completeSignIn`
            // sets `stage = .ready` and *then* awaits `loadPlaylists()`, which
            // sets `.loading` on its first line. Releasing here would uncover a
            // grid that is empty for a reason nothing on screen can express.
            return false

        case .libraryLoading(let loaded):
            // **"The first page has landed."** Not the page's `total`, which
            // arrives on the same response and would be satisfied by one
            // carrying no usable playlists at all; and not `.ready`, which is
            // every page of a library that might hold four hundred. One real row
            // is the least that makes the library worth uncovering.
            return loaded > 0

        case .libraryReady:
            return true

        case .libraryFailed:
            // The library draws `ErrorRow` and offers Try Again, which ADR-0015
            // kept precisely because a failure is the one wait that *is*
            // actionable. Holding a splash in front of the only state the
            // listener can do something about is the worst of the four options.
            return true
        }
    }
}
