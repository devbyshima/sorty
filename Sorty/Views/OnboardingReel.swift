import SwiftUI

/// The looping feature reel that opens the app when no account is connected.
///
/// Beam's `LoopOnBoarding` in Sorty's colour, built out of the same
/// `OnboardingPage` the connect steps use - so the reel's three screens and the
/// flow's four are one screen with different words in it, levelled by
/// construction rather than by two layouts kept in agreement by hand.
///
/// The phase advances on a `TimelineView`, so nothing has to be told to tick.
///
/// **The whole page transitions, glyph included.** It used to be only the words:
/// the symbol swapped underneath via `contentTransition`, so half the screen
/// pushed up and the other half cross-dissolved in place, which is a difference
/// you feel without being able to name. Now the page moves as one, exactly as a
/// connect step does.
///
/// **It never runs under Reduce Motion**, and that is decided by the caller
/// rather than by a branch in here: an auto-advancing reel is not a bounce that
/// can be turned off, it is movement that *is* the design. `SignedOutView` shows
/// the same three points as a still list instead, which is what this screen was
/// before the reel and is the honest reduced form of it.
struct OnboardingReel: View {
    struct Phase: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let body: String
    }

    let phases: [Phase]

    /// How long each phase holds. Beam's is 3s and `OnboardingGlyph`'s bounce
    /// keyframes are cut to fit it exactly - 1.75s of movement, then 1.25s still
    /// - so changing this without changing those leaves the symbol bouncing into
    /// its own replacement.
    private let phaseDuration: TimeInterval = 3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.periodic(from: startDate, by: phaseDuration)) { context in
            let elapsed = startDate.distance(to: context.date)
            let index = max(0, Int(elapsed / phaseDuration)) % max(phases.count, 1)

            ZStack {
                ForEach(phases.indices, id: \.self) { phase in
                    if phase == index {
                        OnboardingPage(
                            symbol: phases[phase].symbol,
                            bounces: true,
                            title: phases[phase].title,
                            text: phases[phase].body,
                            glyphTop: OnboardingMetrics.reelGlyphTop
                        )
                        .transition(.onboardingPage(reduceMotion: reduceMotion))
                    }
                }
            }
            .animation(.bouncy(duration: 0.8), value: index)
        }
    }
}
