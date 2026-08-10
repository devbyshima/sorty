import SwiftUI

/// One onboarding screen: glyph, heading, a line or two, and whatever the screen
/// needs under that.
///
/// **This is the way-in screen's layout, and the other four adopt it** - which is
/// the right way round and was not, briefly. Levelling them the first time
/// flattened the reel into a top-anchored stack to match the steps, and lost the
/// composition that was worth keeping: a glyph floating in the middle of the
/// screen with the words low, near the thing you tap.
///
/// So the words keep the reel's placement - pinned to the *bottom* of whatever
/// space the screen has, in a block of fixed height - and the glyph is pinned to
/// the top. Both are measured from an edge rather than from the content between
/// them, which is the whole reason they hold still.
///
/// The glyph *was* centred, as the reel had it, and centring turns out not to
/// level anything: each screen centres in a different amount of room, so the same
/// code put the symbol 35pt lower on the four steps than on the first page.
///
/// A step with controls puts them under that block, which pushes its words up by
/// exactly the controls' height. That is the one intended difference: steps
/// without controls line up with the reel to the pixel, and steps with them make
/// the room they need.
struct OnboardingPage<Extra: View>: View {
    let symbol: String
    var bounces: Bool = false
    let title: String
    let text: String

    /// Shown as an ⓘ beside the text when there is more to read.
    var onInfo: (() -> Void)?

    /// Distance from the top of this screen's own space down to the glyph.
    ///
    /// **Fixed, because centring cannot level these screens.** Each one centres
    /// in a different amount of room - the connect flow loses a toolbar off the
    /// top and gains a shorter footer at the bottom than the way-in screen's
    /// button-plus-small-print - so the same centred glyph landed 35pt lower on
    /// the four steps than on the first page. Measured, after stacking the same
    /// band from all five shots on top of each other, which is the only way this
    /// kind of drift is visible at all.
    ///
    /// The two values in `OnboardingMetrics` differ by exactly that arithmetic
    /// and put the glyph at the same place on the screen on all five.
    var glyphTop: CGFloat

    /// Last, so it can be written as a trailing closure.
    @ViewBuilder var extra: Extra

    private let wordsHeight: CGFloat = 130

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0).frame(height: glyphTop)

            OnboardingGlyph(symbol: symbol, bounces: bounces)

            // Absorbs whatever is left, which is what keeps the words on the
            // bottom edge while the glyph stays on the top one. Both are then
            // measured from an edge rather than from the content between them,
            // which is the whole reason they hold still.
            Spacer(minLength: 24)

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text(title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(text)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if let onInfo {
                            Button(action: onInfo) {
                                Image(systemName: "info.circle")
                                    .font(.footnote)
                                    .foregroundStyle(SortyTheme.accent)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("More about this step")
                        }
                    }
                }
                .frame(height: wordsHeight, alignment: .top)
                .accessibilityElement(children: .combine)

                extra
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension OnboardingPage where Extra == EmptyView {
    init(
        symbol: String,
        bounces: Bool = false,
        title: String,
        text: String,
        onInfo: (() -> Void)? = nil,
        glyphTop: CGFloat
    ) {
        self.init(
            symbol: symbol,
            bounces: bounces,
            title: title,
            text: text,
            onInfo: onInfo,
            glyphTop: glyphTop,
            extra: { EmptyView() }
        )
    }
}

extension AnyTransition {
    /// How every onboarding page arrives: up from below, blur-replacing.
    ///
    /// One transition for the whole flow, on the reel's pages and the connect
    /// steps alike. A flow whose pages each arrive differently reads as several
    /// flows, and the reel used to be the odd one out in a subtler way than it
    /// looked - its words pushed while its glyph only swapped symbols, so half
    /// the screen changed one way and half another.
    ///
    /// **One edge, not an asymmetric pair.** `push(from:)` describes both halves:
    /// it enters from the named edge and exits to the *opposite* one. Writing
    /// `insertion: .bottom, removal: .top` looks like "in from below, out through
    /// the top" and means the reverse (ADR-0016).
    static func onboardingPage(reduceMotion: Bool) -> AnyTransition {
        reduceMotion
            ? .opacity
            : .push(from: .bottom).combined(with: AnyTransition(.blurReplace))
    }
}


/// Where each onboarding screen puts its glyph, measured from the top of its own
/// space.
///
/// The two differ by the chrome the connect flow carries and the way-in screen
/// does not: a toolbar above, and a shorter block below than the way-in screen's
/// button plus its line of small print. Kept side by side so a change to one is
/// made next to the reason the other exists.
enum OnboardingMetrics {
    static let reelGlyphTop: CGFloat = 220
    static let flowGlyphTop: CGFloat = 176
}
