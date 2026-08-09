import SwiftUI

/// A cover that behaves like a sticker.
///
/// It presses in where the finger lands, leans away from it, and springs flat
/// with a little overshoot when released. The geometry is `StickerTilt` in
/// SortyKit; this applies it.
///
/// **There is no sheen, and that is a compliance decision rather than a taste
/// one.** It used to carry a radial highlight that stayed put while the surface
/// turned under it, which is what made the lean read as a physical surface.
/// Spotify's design guidelines say artwork "must be kept in its original form"
/// and that this "includes applying overlays", and a highlight blended over the
/// cover is an overlay. ADR-0012 removed it and kept the lean.
///
/// **Why a gesture recogniser rather than `DragGesture`.** `DragGesture`
/// defaults to a `minimumDistance` of 10, so a finger placed and held without
/// moving never fires it - and a sticker that only responds once you have
/// already slid your thumb across it is not a sticker. A zero-duration long
/// press reports the touch the instant it lands.
///
/// **Reduce Motion removes the lean entirely.** The effect carries no
/// information, so the accessible version is simply the cover.
struct StickerCover: View {
    let images: [SpotifyImage]
    var cornerRadius: Double = 10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tilt: StickerTilt = .resting
    @State private var isPressed = false

    var body: some View {
        GeometryReader { proxy in
            CoverImage(images: images)
                .clipShape(.rect(cornerRadius: cornerRadius))
                // Applied in this order on purpose: the press scales the whole
                // thing, then the lean turns it. Reversed, the scale would be
                // measured in the rotated frame and the cover would appear to
                // shrink towards a corner.
                .scaleEffect(isPressed && !reduceMotion ? StickerTilt.pressedScale : 1)
                .rotation3DEffect(.degrees(tilt.pitch), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                .rotation3DEffect(.degrees(tilt.yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .gesture(touch(in: proxy.size), isEnabled: !reduceMotion)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func touch(in size: CGSize) -> some Gesture {
        // Zero minimum distance, so a stationary press registers. `sequenced`
        // rather than `simultaneously`: the press has to win before the drag
        // starts reporting, or a scroll that begins on the cover would tilt it
        // on the way past.
        LongPressGesture(minimumDuration: 0)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(_, let drag) = value else { return }
                let point = drag?.location ?? CGPoint(x: size.width / 2, y: size.height / 2)
                withAnimation(.interactiveSpring(duration: 0.18)) {
                    isPressed = true
                    tilt = StickerTilt.at(point: point, in: size)
                }
            }
            .onEnded { _ in settle() }
    }

    /// The overshoot is the whole character of the thing. A sticker released
    /// from a lean does not glide back to flat, it snaps past and settles, so
    /// the spring is deliberately under-damped where every other animation in
    /// the app is `.snappy`.
    private func settle() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.42)) {
            isPressed = false
            tilt = .resting
        }
    }
}
