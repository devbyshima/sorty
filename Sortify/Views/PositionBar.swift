import SwiftUI

/// Where one value sits within the playlist's range for its Attribute.
///
/// The magnitude is carried by **length**, never by hue: a listener who cannot
/// separate the fill from the track still reads the bar by how far it goes, and
/// the accent colour is the same at every value. That is user story 62 — bars
/// distinguishable without relying on colour alone — and it is why there is no
/// low-is-red, high-is-green gradient here.
///
/// One component, used by the rows now and by the track detail sheet in ticket
/// 06, so a value means the same thing in both places.
struct PositionBar: View {
    /// 0 at the playlist's lowest value for this Attribute, 1 at its highest.
    let fraction: Double

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
    private var fillWidth: Double { max(scaledWidth * fraction, 2 * scale) }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.quaternary)
                .frame(width: scaledWidth, height: scaledHeight)

            Capsule()
                .fill(SortifyTheme.accent)
                .frame(width: fillWidth, height: scaledHeight)
        }
        .accessibilityHidden(true)
    }
}
