import SwiftUI

/// The looping feature reel that opens the app when no account is connected.
///
/// A port of Beam's `LoopOnBoarding` in Sorty's colour: three pulse rings
/// expanding out from behind a symbol that bounces in time with them, and the
/// value props pushing up and blur-replacing underneath. The phase advances on a
/// `TimelineView`, so nothing has to be told to tick.
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

    /// How long each phase holds. Beam's is 3s and the bounce keyframes below
    /// are cut to fit it exactly - 1.75s of movement, then 1.25s still - so
    /// changing this without changing them leaves the symbol bouncing into its
    /// own replacement.
    private let phaseDuration: TimeInterval = 3

    private let iconSize: CGFloat = 100
    private let iconScale: CGFloat = 1.25

    @State private var startDate = Date()

    var body: some View {
        ZStack {
            pulseRings

            TimelineView(.periodic(from: startDate, by: phaseDuration)) { context in
                let elapsed = startDate.distance(to: context.date)
                let index = max(0, Int(elapsed / phaseDuration)) % max(phases.count, 1)

                ZStack {
                    icon(phases[index].symbol)
                        .padding(.bottom, 130)

                    ZStack {
                        ForEach(phases.indices, id: \.self) { phase in
                            if phase == index {
                                text(phases[phase])
                                    .transition(
                                        .asymmetric(
                                            insertion: .push(from: .bottom),
                                            removal: .push(from: .bottom)
                                        )
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
    }

    private func icon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: iconSize - 30))
            .foregroundStyle(SortyTheme.accent.gradient)
            // The symbol swaps rather than cuts, so one prop becomes the next
            // instead of two unrelated glyphs alternating.
            .contentTransition(.symbolEffect(.replace.downUp))
            .frame(width: iconSize, height: iconSize)
            // Three bounces, timed to land on the three rings.
            .keyframeAnimator(initialValue: 1.0, repeating: true) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                MoveKeyframe(1)
                SpringKeyframe(1, duration: 0.25)
                SpringKeyframe(iconScale, duration: 0.25)
                SpringKeyframe(1, duration: 0.25)
                SpringKeyframe(iconScale, duration: 0.25)
                SpringKeyframe(1, duration: 0.25)
                SpringKeyframe(iconScale, duration: 0.25)
                SpringKeyframe(1, duration: 0.25)
                CubicKeyframe(1, duration: 1.25)
            }
            .accessibilityHidden(true)
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

    /// Three rings, staggered so one is always leaving as another arrives.
    ///
    /// **The rings live in an `.overlay` on an empty `Color`, and that is
    /// structural rather than stylistic.** A ring grows to twelve times its own
    /// size - about 600pt - and a laid-out view that wide sizes everything above
    /// it: the reel became 600pt across, then so did this screen's stack, and
    /// the value props and the Connect button were laid out to a width half of
    /// which was off both edges of the display. An overlay never reports a size
    /// to its parent, so the rings can be as large as they like.
    ///
    /// Beam does the same thing with `Rectangle().foregroundStyle(.clear)`, and
    /// flattening that into a plain `ZStack` is what broke it here.
    private var pulseRings: some View {
        Color.clear
            .overlay {
                ZStack {
                    pulseRing(delay: 0, wait: 1)
                    pulseRing(delay: 0.5, wait: 0.5)
                    pulseRing(delay: 1, wait: 0)
                }
            }
            .padding(.bottom, 130)
            .accessibilityHidden(true)
    }

    private func pulseRing(delay: CGFloat, wait: CGFloat) -> some View {
        let size = iconSize / 2

        return KeyframeAnimator(initialValue: Pulse(), repeating: true) { pulse in
            Circle()
                .stroke(SortyTheme.accent.opacity(0.6), lineWidth: 1.3)
                .frame(width: size * pulse.scale, height: size * pulse.scale)
                // Fades with distance travelled as well as with its own keyframe,
                // so a ring thins out as it grows rather than vanishing at once.
                .opacity((pulse.scale - 1) / 3)
                .opacity(pulse.opacity)
        } keyframes: { _ in
            MoveKeyframe(Pulse())
            LinearKeyframe(Pulse(), duration: delay)
            LinearKeyframe(Pulse(scale: 12, opacity: 0), duration: 2)
            LinearKeyframe(Pulse(scale: 12, opacity: 0), duration: wait)
        }
    }

    private struct Pulse: Animatable {
        var scale: CGFloat = 1
        var opacity: CGFloat = 1

        var animatableData: AnimatablePair<CGFloat, CGFloat> {
            get { AnimatablePair(scale, opacity) }
            set {
                scale = newValue.first
                opacity = newValue.second
            }
        }
    }
}
