import SwiftUI

/// A screen's own top bar, with the progressive blur as its background.
///
/// **Why not the system navigation bar.** The blur belongs *to* the bar - it is
/// the bar's background, the way the library screen's blur is the background of
/// its title-and-chips header. A `UINavigationBar` cannot be given one: its
/// background is drawn by UIKit and is either a hard-edged material or nothing,
/// and the bar composites above anything a view can attach. So a blur meant to
/// be the bar's own backing could only be placed as a separate band underneath
/// it - a second object, with its own edge, that had to be kept from reaching
/// far enough to blur the bar's contents or the controls below it. Owning the
/// bar removes the whole problem: content scrolls under it, the blur is behind
/// its label and buttons, and there is one surface instead of two.
///
/// The library screen builds its header exactly this way. This is that pattern,
/// shared, so the three screens that scroll content under chrome agree.
struct ScreenTopBar<Leading: View, Trailing: View>: View {
    let title: String
    /// Handed straight to `TopBlur`, whose default is the one dispersion every
    /// screen shares. Not overridden anywhere.
    var fade: CGFloat = 20
    /// 0 inside a sheet, whose own top edge is already the top of the world and
    /// where reaching past it draws over the presenting screen.
    var overscan: CGFloat = 200
    /// Space above the bar's contents.
    ///
    /// 3 under a status bar, which has already put the whole notch between the
    /// screen edge and this. A sheet has nothing above it but its own rounded
    /// corner, so its title and close button need the room found for them here
    /// instead.
    var topPadding: CGFloat = 3
    /// Whether this draws a blur at all.
    ///
    /// False while a pinned row directly beneath carries one. That row's band
    /// overscans upward, so it already covers this bar *and* the status bar
    /// above it - drawing a second one here would stack two backdrops over the
    /// bar's own height and leave it visibly stronger than the strip above,
    /// which is the band that kept appearing across the middle of the chrome.
    /// One blur, one source, for the whole combined header.
    var showsBlur: Bool = true
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Seeded to the height this actually lays out at rather than a guess.
    ///
    /// It is the scroll view's top content inset once this is a
    /// `safeAreaInset`, and an inset that changes a frame after the first
    /// layout moves the content under it without adjusting the offset - which
    /// is a sheet that opens looking as though it has already been scrolled.
    @State private var height: CGFloat = TopBarMetrics.side + 6


    @ScaledMetric(relativeTo: .headline) private var scaledSide: Double = TopBarMetrics.side

    var body: some View {
        // Derived from the buttons rather than guessed, so the title cannot
        // slide underneath them at any text size.
        let clear = TopBarMetrics.clamped(scaledSide) + 12

        return ZStack {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, clear)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 12) {
                leading
                Spacer(minLength: 8)
                trailing
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        // 3 below a 44pt control is the 50pt an inline navigation bar occupies
        // once its own padding is counted, which is what this replaced.
        .padding(.top, topPadding)
        .padding(.bottom, 3)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .background(alignment: .top) {
            if showsBlur {
                TopBlur(height: height, fade: fade, overscan: overscan)
            }
        }
    }
}

enum TopBarMetrics {
    /// The system's own inline-navigation-bar control size, and the size the
    /// library screen's menu already used. Both bars were 38 while the library
    /// was 44, so the same affordance changed size between screens.
    static let side: CGFloat = 44

    /// The circles scale with Dynamic Type so the glyph inside stays contained,
    /// but not without limit: unclamped, two circles at the largest
    /// accessibility size are ~97pt each and meet in the middle of the bar, so
    /// the title had nowhere to be and truncated to a fragment behind them.
    static let maxSide: CGFloat = 60

    static func clamped(_ scaled: Double) -> CGFloat { min(scaled, maxSide) }
}

/// The round glass button the top bars carry, matching the capsules on the
/// chip rows: glass at rest, interactive under a finger, tinted by its glyph
/// rather than by a fill.
struct TopBarButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    /// Scaled, because the glyph inside it is. `.frame` does not clip, so a
    /// fixed circle around a `.headline` that grows with Dynamic Type left the
    /// mark hanging out of the glass on both sides at accessibility sizes.
    @ScaledMetric(relativeTo: .headline) private var scaledSide: Double = TopBarMetrics.side

    var body: some View {
        let side = TopBarMetrics.clamped(scaledSide)
        return Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: side, height: side)
                .glassEffect(.regular.interactive(), in: .circle)
                .glassEdge(in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
