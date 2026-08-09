import SwiftUI

/// How one onboarding page leaves and the next arrives.
///
/// A page travels, smears with the travel, and fades - rather than sliding at
/// constant sharpness, which is what `.move(edge:)` gives and what reads as a
/// card being dragged across a table.
///
/// **Why a modifier rather than one of SwiftUI's transitions.** A shader
/// argument is not animatable on its own: `.float(progress)` is read once, when
/// SwiftUI builds the view, not interpolated across the animation. `Animatable`
/// is the bridge - SwiftUI drives `animatableData` frame by frame and each frame
/// rebuilds the effect with the current number. `.transition(.modifier(active:
/// identity:))` supplies the two ends.
///
/// The sign carries the direction: `+1` is a page waiting off to the right, `-1`
/// one that has left to the left, `0` a page at rest. A number rather than an
/// edge is deliberate - `push(from:)` describes *both* halves of a transition
/// with a single edge and reads backwards to almost everyone, which cost this
/// project one wrong-direction bug already (ADR-0016).
struct PageTransition: ViewModifier, Animatable {
    var progress: Double

    /// Whether this half of the page carries the motion blur.
    ///
    /// **Interactive controls must not.** A `layerEffect` forces an offscreen
    /// pass, and SwiftUI cannot rasterize a UIKit-backed view that way - it
    /// draws a yellow hatched placeholder with a prohibition sign instead. The
    /// Client ID `TextField` is exactly that, and with the effect over it step 3
    /// rendered its only control as a warning label.
    ///
    /// Gating on `progress == 0` fixed the *resting* case and would still have
    /// flashed the placeholder for the length of every transition into and out
    /// of that step. So the controls travel with the rest of the page - same
    /// distance, same fade, same timing - and simply never go under the shader.
    /// Nothing is lost: a text field smeared during a 300ms slide is not a
    /// legible text field either.
    var smears: Bool = true

    /// A fixed distance rather than a fraction of the width.
    ///
    /// It keeps this off `visualEffect`, which is the only reason the geometry
    /// proxy was here - and `visualEffect` rasterizes too, so reading the width
    /// reintroduced exactly the problem `smears` exists to avoid. Less than a
    /// screen width on purpose: a page travelling its own width leaves a gap of
    /// bare background mid-transition, because the page behind it is doing the
    /// same thing.
    private static let travel: Double = 120

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        smeared(content)
            .offset(x: progress * Self.travel)
            // Squared, so a page stays legible for most of its journey and only
            // gives up at the end. Linear opacity leaves both pages looking
            // half-there for the whole transition.
            .opacity(1 - (progress * progress))
    }

    @ViewBuilder
    private func smeared(_ content: Content) -> some View {
        if smears, abs(progress) > 0.001 {
            content.layerEffect(
                ShaderLibrary.pageSmear(.float(progress)),
                // Only as far as the smear reaches. The travel above is an
                // ordinary offset, so the sampler never needs the screen's width.
                maxSampleOffset: CGSize(width: 40, height: 0)
            )
        } else {
            content
        }
    }
}

extension AnyTransition {
    /// A page arriving from the right and leaving to the left.
    ///
    /// Reduce Motion gets a cross-fade. The smear is the *point* of this
    /// transition, so a shortened or gentler version would be a weaker form of
    /// exactly the thing somebody has asked not to see.
    static func page(reduceMotion: Bool, smears: Bool = true) -> AnyTransition {
        guard !reduceMotion else { return .opacity }

        return .asymmetric(
            insertion: .modifier(
                active: PageTransition(progress: 1, smears: smears),
                identity: PageTransition(progress: 0, smears: smears)
            ),
            removal: .modifier(
                active: PageTransition(progress: -1, smears: smears),
                identity: PageTransition(progress: 0, smears: smears)
            )
        )
    }
}
