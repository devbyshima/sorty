import SwiftUI

/// How one onboarding page leaves and the next arrives.
///
/// A page arrives *through depth* rather than across the screen: the incoming
/// one grows in from slightly behind while the outgoing one carries on past the
/// viewer, both blurring radially as they move.
///
/// It replaced a horizontal slide, which is what `.move(edge:)` gives and reads
/// as a card being dragged across a table. Depth suits a sequence better - four
/// steps are a stack you advance through, not a filmstrip you pan along - and it
/// stops the flow's page change from being the same gesture as the flow's own
/// arrival, which pushes in from the right.
///
/// **Why a modifier rather than one of SwiftUI's transitions.** A shader
/// argument is not animatable on its own: `.float(progress)` is read once, when
/// SwiftUI builds the view, not interpolated across the animation. `Animatable`
/// is the bridge - SwiftUI drives `animatableData` frame by frame and each frame
/// rebuilds the effect with the current number. `.transition(.modifier(active:
/// identity:))` supplies the two ends.
///
/// The sign carries the direction: `+1` is a page still behind the viewer, `-1`
/// one that has passed and is receding, `0` a page at rest. A number rather than
/// an edge is deliberate - `push(from:)` describes *both* halves of a transition
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
    /// Nothing is lost: a text field blurred during a 250ms move is not a
    /// legible text field either.
    var smears: Bool = true

    /// How far a page is from its resting size at either end of the journey.
    ///
    /// Small on purpose. A page is a screenful of type, and type that grows or
    /// shrinks by more than a few percent stops reading as *approaching* and
    /// starts reading as a zoom effect applied to a document.
    private static let depth: Double = 0.06

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        blurred(content)
            // Behind the viewer when arriving, past them when leaving.
            .scaleEffect(1 - (progress * Self.depth))
            // Squared, so a page stays legible for most of its journey and only
            // gives up at the end. Linear opacity leaves both pages looking
            // half-there for the whole transition.
            .opacity(1 - (progress * progress))
    }

    @ViewBuilder
    private func blurred(_ content: Content) -> some View {
        if smears, abs(progress) > 0.001 {
            content.visualEffect { view, proxy in
                view.layerEffect(
                    ShaderLibrary.pageZoom(
                        .float2(proxy.size),
                        .float(progress)
                    ),
                    // The radial reach is a fraction of each pixel's distance
                    // from the centre, so the furthest sample is bounded by the
                    // half-diagonal times that fraction. 60 covers a full-screen
                    // page with room to spare.
                    maxSampleOffset: CGSize(width: 60, height: 60)
                )
            }
        } else {
            content
        }
    }
}

extension AnyTransition {
    /// A page arriving from behind and leaving past the viewer.
    ///
    /// Reduce Motion gets a cross-fade. Scaling type toward and away from the
    /// viewer is precisely the kind of movement the setting exists to stop, and
    /// a gentler version of it would be a weaker form of the same thing.
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
