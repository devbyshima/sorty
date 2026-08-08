import SwiftUI

/// Where one value sits within the playlist's range for its Attribute.
///
/// The magnitude is carried by **length**, never by hue: a listener who cannot
/// separate the fill from the track still reads the bar by how far it goes, and
/// the accent colour is the same at every value. That is user story 62 - bars
/// distinguishable without relying on colour alone - and it is why there is no
/// low-is-red, high-is-green gradient here.
///
/// One component, used by the rows and by the track detail sheet, so a value
/// means the same thing in both places.
struct PositionBar: View {
    /// 0 at the playlist's lowest value for this Attribute, 1 at its highest.
    let fraction: Double

    /// Takes the width it is given instead of a fixed one.
    ///
    /// A row sits its bar beside a number in a column of its own, where a fixed
    /// width is what keeps the bars aligned down the list. The detail sheet
    /// gives each Attribute a line to itself, where a bar stopping short of the
    /// margin would read as a shorter *value* rather than a narrower component.
    /// Same bar, same meaning, measured against whatever line it is drawn on.
    var fillsWidth: Bool = false

    var width: Double = 56
    var height: Double = 4

    /// Grows with the text, so the bar doesn't shrink to a speck beside
    /// accessibility-sized numbers.
    @ScaledMetric(relativeTo: .subheadline) private var scale: Double = 1

    private var scaledWidth: Double { width * scale }
    private var scaledHeight: Double { height * scale }

    /// The track behind the fill is what says "this was measured", so the fill
    /// itself is free to be nearly nothing at the bottom of the range. A floor
    /// any larger than a dot would make every value in the lowest few per cent
    /// draw the same length, and the bar would stop tracking the number beside
    /// it. A track with no value renders no bar at all, so an empty-looking
    /// fill is never mistaken for missing data.
    private var minimumFill: Double { 2 * scale }

    private func fillWidth(within available: Double) -> Double {
        max(available * fraction, minimumFill)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(SortifyTheme.accentTrack)

            if fillsWidth {
                // The fraction is of a width only the layout knows, so it has
                // to be measured. The reader is a child of the ZStack rather
                // than a wrapper around it, so the bar's own height still comes
                // from the frame below and not from a greedy proposal.
                GeometryReader { proxy in
                    Capsule()
                        .fill(SortifyTheme.accent)
                        .frame(width: fillWidth(within: proxy.size.width))
                }
            } else {
                Capsule()
                    .fill(SortifyTheme.accent)
                    .frame(width: fillWidth(within: scaledWidth))
            }
        }
        .frame(width: fillsWidth ? nil : scaledWidth, height: scaledHeight)
        .accessibilityHidden(true)
    }
}
