import SwiftUI

/// The shape of something that hasn't arrived.
///
/// Sorty already had one of these - `CoverRipple`, which stands in for a cover
/// while its file is on the way. This is the same idea for everything that is
/// not square: a name, an artist, a count. **Cover-shaped placeholders keep
/// using `CoverRipple`** and nothing here touches them, which also keeps every
/// shader in the app on the same side of the compliance boundary ADR-0015 drew.
///
/// **Deliberately not a shader, and deliberately not a shimmer.**
///
/// Not a shader because a `[[stitchable]]` function that fails to resolve is
/// silently skipped and SwiftUI draws the unmodified view - which here is a flat
/// grey bar, exactly what success looks like. ADR-0015 built two screenshots to
/// catch that failure on two shaders; a third one across twenty call sites is
/// more surface than the texture is worth. `coverRipple`'s rings are
/// square-specific anyway: it normalises against `size` and takes
/// `length(uv - 0.5)`, so on a 140x12 bar they stretch into extreme ellipses,
/// and its own comment already warns about aliasing at 44pt.
///
/// Not a shimmer because a band travelling left to right across a list is a
/// progress readout wearing texture's clothes, and ADR-0015 removed four of
/// those. A breath says "not yet". A sweep says "thirty-eight percent of the way
/// there", which is a claim this app cannot make and has decided not to make.
///
/// The breath is `coverRipple`'s own, moved out of Metal: the shader modulates
/// by `0.78 + 0.22 * sin((time + phase) * 0.7)`, which is a nine-second cycle at
/// twenty-two percent, and this is that figure expressed as a repeating
/// animation so a placeholder tile and the two bars under it are visibly the
/// same material. ADR-0019.
enum Skeleton {
    /// The resting fill.
    ///
    /// **Not `SortyTheme.surface`, and that is a measurement rather than a
    /// preference.** `surface` is pure white in light, and these bars sit on
    /// `background`, which is a *tinted* near-white - so a surface-coloured bar
    /// in light is lighter than the field it is drawn on and effectively
    /// invisible. `CoverRipple` gets away with `surface` because a cover tile
    /// carries a card shadow describing its edge; a text bar has no such help.
    /// `raisedSurface` is the token that is a step away from the field in *both*
    /// Appearances, which is the property a bar needs.
    static var low: Color { SortyTheme.raisedSurface }

    /// `CoverRipple.high`, to the value, so a placeholder cover and the bars
    /// beneath it move between the same pair of greys.
    static func high(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.26) : Color(white: 0.87)
    }

    /// Half a cycle; it autoreverses, so the breath is nine seconds.
    ///
    /// **Far outside the app's 0.14-0.25s transition budget, on purpose.** That
    /// budget is for transitions, and a transition is a thing that ends. This is
    /// ambient texture on a surface that may be there for six seconds, and the
    /// same rule that makes a 0.18s cross-fade right makes a 0.18s pulse read as
    /// an error light.
    static let period: Double = 4.5
}

/// A placeholder in a given shape.
///
/// **Reduce Motion holds it still**, which is the branch `CoverRipple` takes and
/// for the same reason: the breath carries no information the stillness doesn't,
/// so a listener who asked for less movement loses nothing.
///
/// Hidden from VoiceOver unconditionally. What a loading region *says* is
/// decided once, on the container - see `SkeletonRegion`.
///
/// `repeatForever` rather than `TimelineView`: `CoverRipple` needs a `time`
/// uniform every frame because a `colorEffect` has no other way to move, and
/// this does not. A two-value interpolation is what SwiftUI's animator drives on
/// the render server without re-evaluating any view body, where a grid of twelve
/// placeholder tiles carrying three bars each would be thirty-six
/// `TimelineView`s invalidating at display rate inside a `LazyVGrid`.
struct SkeletonShape<S: Shape>: View {
    let shape: S
    var index: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var breathing = false

    var body: some View {
        shape
            .fill(breathing ? Skeleton.high(colorScheme) : Skeleton.low)
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: Skeleton.period)
                        .repeatForever(autoreverses: true)
                        .delay(SkeletonPlan.phase(at: index, period: Skeleton.period)),
                value: breathing
            )
            .onAppear { breathing = true }
            .accessibilityHidden(true)
    }
}

/// One line of text that hasn't arrived.
///
/// **The height comes from the type, not from a number.** A hard 12pt bar is
/// right at one Dynamic Type size and wrong at the other eleven, and every tile
/// this stands in for *reserves* its lines - `PlaylistTile` uses
/// `lineLimit(2, reservesSpace: true)` for exactly that reason - so a guessed
/// height is a guaranteed reflow at the handoff, which is the one thing this
/// whole exercise exists to prevent. A hidden `Text` in the same font measures
/// precisely what the real row will measure, at every size, for free.
///
/// The width is a fraction rather than a length, because a name column is
/// whatever the layout gives it: a fixed 140pt bar would overhang a three-up
/// tile and underfill a list row.
struct SkeletonLine: View {
    let font: Font
    var widthFraction: Double = 1
    var index: Int = 0

    var body: some View {
        Text(verbatim: " ")
            .font(font)
            .hidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    SkeletonShape(shape: Capsule(), index: index)
                        .frame(width: max(proxy.size.width * widthFraction, 8))
                }
            }
    }
}

/// A run of placeholders, and the one thing VoiceOver hears about them.
///
/// The shapes are all `accessibilityHidden`, so without this a screen of them is
/// silent - a listener using VoiceOver would meet a heading and then nothing,
/// which is indistinguishable from an empty library. One label on the container
/// says the one true thing, and it is a *status* rather than content: it is not
/// a button, it has no value, and it will be replaced by the rows themselves.
struct SkeletonRegion<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.updatesFrequently)
    }
}
