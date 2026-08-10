import SwiftUI

/// The looping feature reel that opens the app when no account is connected.
///
/// A port of Beam's `LoopOnBoarding` in Sorty's colour: `OnboardingGlyph` above,
/// bouncing in time with its own rings, and the value props pushing up and
/// blur-replacing underneath. The phase advances on a `TimelineView`, so nothing
/// has to be told to tick.
///
/// The glyph is shared with the connect steps, which is what makes the five
/// onboarding screens one screen with different words in it.
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

    @State private var startDate = Date()

    var body: some View {
        TimelineView(.periodic(from: startDate, by: phaseDuration)) { context in
            let elapsed = startDate.distance(to: context.date)
            let index = max(0, Int(elapsed / phaseDuration)) % max(phases.count, 1)

            ZStack {
                OnboardingGlyph(symbol: phases[index].symbol, bounces: true)
                    .padding(.bottom, 130)

                ZStack {
                    ForEach(phases.indices, id: \.self) { phase in
                        if phase == index {
                            text(phases[phase])
                                // Up from the bottom, and every onboarding page
                                // now moves the same way.
                                //
                                // **One edge, not an asymmetric pair.**
                                // `push(from:)` describes both halves: it enters
                                // from the named edge and exits to the *opposite*
                                // one. Writing `insertion: .bottom, removal:
                                // .top` looks like "in from below, out through
                                // the top" and means the reverse.
                                .transition(
                                    .push(from: .bottom)
                                        .combined(with: AnyTransition(.blurReplace))
                                )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .animation(.bouncy(duration: 0.8), value: index)
            }
        }
    }

    private func text(_ phase: Phase) -> some View {
        VStack(spacing: 12) {
            Text(phase.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(phase.body)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(height: 130, alignment: .top)
        .accessibilityElement(children: .combine)
    }
}
