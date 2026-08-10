import Observation
import SwiftUI

/// Holds the launch splash until there is something behind it.
///
/// **All it does is hold a start instant and ask `LaunchReadiness`.** Every rule
/// is over there in SortyKit, where it is a truth table with tests against it;
/// this is here in the app because it reads a real clock, and a type that reads
/// a real clock is a type a test has to wait for.
///
/// It never re-arms. `handleAuthCallback` sets `stage` back to `.connecting`
/// when somebody signs in again, and a gate that re-armed on that would drop a
/// full-screen splash over an app the listener is already using.
@MainActor
@Observable
final class LaunchGate {
    /// True while the splash should cover the app.
    private(set) var isCovering = true

    private let start = ContinuousClock.now
    private var settled = false

    /// Called on every change of `launchProgress`.
    func update(_ progress: LaunchReadiness.Progress, reduceMotion: Bool) {
        guard !settled else { return }
        guard LaunchReadiness.isSatisfied(
            progress,
            elapsed: ContinuousClock.now - start,
            reduceMotion: reduceMotion
        ) else { return }
        settled = true
        isCovering = false
    }

    /// The two deadlines, because a state change is not the only thing that can
    /// make the answer true.
    ///
    /// **The floor is a deadline, and forgetting that hung the splash for six
    /// seconds.** Against a fast connection - or the demo catalogue, which is
    /// how this was caught - every stage change lands inside the first 700ms, so
    /// each one is evaluated while the floor still says no, and then nothing
    /// changes again. Watching `launchProgress` alone means the gate has no
    /// third event to open on and falls through to the ceiling. So the moment
    /// the floor expires is itself an event.
    ///
    /// **The ceiling is a deadline for the mirror-image reason.** A stalled
    /// `restore()` publishes nothing, so there is no event to evaluate the
    /// timeout on, and the splash would sit there for as long as `URLSession`
    /// felt like waiting. This is the difference between a rule and a hope.
    func run(progress: @escaping @MainActor () -> LaunchReadiness.Progress,
             reduceMotion: Bool) async {
        let floor = reduceMotion ? .zero : LaunchReadiness.minimum
        // A hair past each, so a deadline loses every race with a real answer
        // and only ever fires when there wasn't one.
        let slack = Duration.milliseconds(20)

        try? await Task.sleep(for: floor + slack)
        guard !Task.isCancelled else { return }
        update(progress(), reduceMotion: reduceMotion)
        guard !settled else { return }

        try? await Task.sleep(for: LaunchReadiness.timeout - floor)
        guard !Task.isCancelled else { return }
        update(progress(), reduceMotion: reduceMotion)
    }
}
