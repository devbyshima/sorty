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
/// **The glyph holds still and only the words move**, which is the one place
/// this screen differs from a connect step - and it is a real difference, not an
/// oversight. A step is a page you have moved to, so the whole page arrives. The
/// reel is one screen talking, and its glyph is mid-animation: bouncing in time
/// with its own rings. Sliding it away three seconds in interrupts an animation
/// that is meant to be continuous and restarts it from nothing. The symbol swaps
/// in place instead, which is what `contentTransition` on `OnboardingGlyph` is
/// for.
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

            VStack(spacing: 0) {
                Spacer(minLength: 0).frame(height: OnboardingMetrics.reelGlyphTop)

                // Outside the transition below, so it stays where it is.
                OnboardingGlyph(symbol: phases[index].symbol, bounces: true)

                Spacer(minLength: OnboardingMetrics.glyphGap)

                ZStack {
                    ForEach(phases.indices, id: \.self) { phase in
                        if phase == index {
                            OnboardingWords(
                                title: phases[phase].title,
                                text: phases[phase].body
                            )
                            .transition(.onboardingPage(reduceMotion: reduceMotion))
                        }
                    }
                }
                .frame(height: OnboardingMetrics.wordsHeight)
                .animation(.bouncy(duration: 0.8), value: index)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
