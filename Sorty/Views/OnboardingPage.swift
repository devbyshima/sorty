import SwiftUI

/// One onboarding screen: glyph, heading, a line or two, and whatever the screen
/// needs under that.
///
/// Every screen in the flow is one of these - the three the reel cycles through
/// and the four connect steps - which is the only way they stay levelled. They
/// were laid out separately before, and drifted: the reel centred its glyph with
/// a fixed 130 beneath it while the steps floated theirs between two `Spacer`s,
/// so the symbol and the heading sat at different heights on either side of a
/// single flow, and moved again between steps as each page's text changed length.
///
/// **The offsets above the heading are fixed, and that is the whole mechanism.**
/// Anything centred, or spaced by a `Spacer` at both ends, moves when its content
/// changes length. Fixing the distance from the top to the glyph and from the
/// glyph to the heading means every page puts them in the same place, and pages
/// with more to say grow downward into the space below.
struct OnboardingPage<Extra: View>: View {
    let symbol: String
    var bounces: Bool = false
    let title: String
    let text: String

    /// Shown as an ⓘ beside the text when there is more to read.
    var onInfo: (() -> Void)?

    /// Distance from the top of the screen's own safe area to the glyph.
    ///
    /// Passed in rather than fixed here because the two callers do not share a
    /// top edge: the connect flow has a toolbar and the way-in screen does not,
    /// so the same number would put the flow's glyph a toolbar's height lower.
    var topInset: CGFloat

    /// Trailing, so it can be written as a trailing closure.
    @ViewBuilder var extra: Extra

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0).frame(height: topInset)

            OnboardingGlyph(symbol: symbol, bounces: bounces)

            Spacer(minLength: 0).frame(height: 40)

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
            // A floor, so a one-line page and a three-line one still put whatever
            // follows in the same place. Not a fixed height: the longest of these
            // would then be clipped rather than allowed to push down.
            .frame(minHeight: 104, alignment: .top)
            .accessibilityElement(children: .combine)

            extra

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}

extension OnboardingPage where Extra == EmptyView {
    init(
        symbol: String,
        bounces: Bool = false,
        title: String,
        text: String,
        onInfo: (() -> Void)? = nil,
        topInset: CGFloat
    ) {
        self.init(
            symbol: symbol,
            bounces: bounces,
            title: title,
            text: text,
            onInfo: onInfo,
            topInset: topInset,
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

/// The two numbers that level the onboarding's five screens against each other.
///
/// They differ by exactly the toolbar the connect flow carries and the way-in
/// screen does not. Kept together so a change to one is made next to the reason
/// the other exists; separated in two files, they drifted once already.
enum OnboardingMetrics {
    /// The way-in screen, which has no bar above it.
    static let reelTopInset: CGFloat = 96

    /// The connect flow, whose toolbar has already pushed its content down.
    static let flowTopInset: CGFloat = 40
}
