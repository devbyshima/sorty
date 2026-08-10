import SwiftUI

/// The symbol every onboarding screen leads with: three pulse rings expanding
/// out from behind an accent glyph.
///
/// Shared so the way-in screen and the four connect steps are the *same screen
/// with different words*, which is what Beam's onboarding does and what this was
/// pulled out of `OnboardingReel` to achieve. Before it, the reel had a 100pt
/// symbol ringed with pulses and the connect steps had a 44pt one with nothing
/// behind it, and the two halves of one flow looked like two apps.
struct OnboardingGlyph: View {
    let symbol: String

    /// Whether the glyph bounces in time with the rings.
    ///
    /// The reel bounces because it is cycling - the movement is what says
    /// another prop is coming. A connect step is not going anywhere until
    /// somebody taps, so it holds still: a glyph that bounces forever on a
    /// screen waiting for a decision reads as something loading.
    var bounces: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let size: CGFloat = 100
    private let bounceScale: CGFloat = 1.25

    var body: some View {
        ZStack {
            if !reduceMotion {
                pulseRings
            }
            glyph
        }
        .frame(height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var glyph: some View {
        let image = Image(systemName: symbol)
            .font(.system(size: size - 30))
            .foregroundStyle(SortyTheme.accent.gradient)
            // The symbol swaps rather than cuts, so one screen's glyph becomes
            // the next instead of two unrelated shapes alternating.
            .contentTransition(.symbolEffect(.replace.downUp))
            .frame(width: size, height: size)

        if bounces, !reduceMotion {
            image.keyframeAnimator(initialValue: 1.0, repeating: true) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                // Three bounces timed to land on the three rings, then still.
                MoveKeyframe(1)
                SpringKeyframe(1, duration: 0.25)
                SpringKeyframe(bounceScale, duration: 0.25)
                SpringKeyframe(1, duration: 0.25)
                SpringKeyframe(bounceScale, duration: 0.25)
                SpringKeyframe(1, duration: 0.25)
                SpringKeyframe(bounceScale, duration: 0.25)
                SpringKeyframe(1, duration: 0.25)
                CubicKeyframe(1, duration: 1.25)
            }
        } else {
            image
        }
    }

    /// Three rings, staggered so one is always leaving as another arrives.
    ///
    /// **In an `.overlay` on an empty `Color`, and that is structural.** A ring
    /// grows to twelve times its own size - about 600pt - and a laid-out view
    /// that wide sizes everything above it: it once made the way-in screen 600pt
    /// across and laid the Connect button out half off the display. An overlay
    /// never reports a size to its parent. Beam does the same thing with
    /// `Rectangle().foregroundStyle(.clear)`, and flattening it to a `ZStack` is
    /// what broke it (ADR-0016).
    private var pulseRings: some View {
        Color.clear
            .overlay {
                ZStack {
                    pulseRing(delay: 0, wait: 1)
                    pulseRing(delay: 0.5, wait: 0.5)
                    pulseRing(delay: 1, wait: 0)
                }
            }
    }

    private func pulseRing(delay: CGFloat, wait: CGFloat) -> some View {
        KeyframeAnimator(initialValue: Pulse(), repeating: true) { pulse in
            Circle()
                .stroke(SortyTheme.accent.opacity(0.6), lineWidth: 1.3)
                .frame(width: size / 2 * pulse.scale, height: size / 2 * pulse.scale)
                // Fades with distance travelled as well as with its own
                // keyframe, so a ring thins as it grows rather than vanishing.
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
