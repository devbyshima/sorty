import SwiftUI

/// Sortify's mark: four pills of descending length, a set of things put in
/// order.
///
/// The same geometry `scripts/make_icon.swift` renders into the app icon, so
/// the icon on the home screen and the mark inside the app cannot drift apart.
/// The numbers are fractions of the view's own size rather than points, which
/// is what lets one definition serve a 1024pt icon and a 44pt glyph.
struct SortifyMark: View {
    /// Fractions of the drawable width, longest first. Monotonic on purpose:
    /// any bar out of sequence turns "in order" into "a level meter".
    private static let barWidths = [1.0, 0.78, 0.56, 0.34]

    /// Proportions lifted from the icon: a 1024 canvas with a 176 margin, 88pt
    /// bars and 60pt gaps.
    private static let marginFraction = 176.0 / 1024.0
    private static let barHeightFraction = 88.0 / 1024.0
    private static let gapFraction = 60.0 / 1024.0

    var color: Color = .white

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let drawable = side - side * Self.marginFraction * 2
            let barHeight = side * Self.barHeightFraction
            let gap = side * Self.gapFraction

            VStack(alignment: .leading, spacing: gap) {
                ForEach(Array(Self.barWidths.enumerated()), id: \.offset) { _, fraction in
                    Capsule()
                        .fill(color)
                        .frame(width: drawable * fraction, height: barHeight)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The mark on its own accent field, rounded the way the icon is.
struct SortifyMarkTile: View {
    var side: Double = 72

    var body: some View {
        SortifyMark()
            .frame(width: side, height: side)
            .background(SortifyTheme.accent, in: .rect(cornerRadius: side * 0.22))
    }
}
