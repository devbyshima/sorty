import CoreGraphics
import Foundation

/// How a cover leans when a finger is on it.
///
/// The brief was that the cover should behave like a sticker: something
/// physical sitting on the surface that presses in under a fingertip, tips away
/// from it, and springs flat when released. That is a geometry problem rather
/// than a rendering one - where the finger is, how far the thing leans, and
/// where the light lands - so it is resolved here where it can be asserted, and
/// the view only applies the numbers.
public struct StickerTilt: Equatable, Sendable {
    /// Degrees about the horizontal axis. Positive tips the top away.
    public let pitch: Double
    /// Degrees about the vertical axis. Positive tips the right edge away.
    public let yaw: Double
    /// Where the highlight sits, as a unit point across the cover. Travels
    /// opposite the lean, the way a sheen on a real surface stays put while the
    /// surface turns under it.
    public let sheen: CGPoint

    /// Flat, lit from the middle. What Reduce Motion gets, and what a released
    /// cover springs back to.
    public static let resting = StickerTilt(pitch: 0, yaw: 0, sheen: CGPoint(x: 0.5, y: 0.5))

    public init(pitch: Double, yaw: Double, sheen: CGPoint) {
        self.pitch = pitch
        self.yaw = yaw
        self.sheen = sheen
    }

    /// The lean produced by a touch at `point` within a cover of `size`.
    ///
    /// The touch is clamped to the cover: a drag that continues past the edge
    /// keeps its last meaningful lean rather than winding up to an angle the
    /// finger never reached. `maxAngle` is small on purpose - the effect wanted
    /// is a sticker pressed against a surface, not a card being flipped, and
    /// past about fifteen degrees the artwork starts to read as skewed rather
    /// than tilted.
    public static func at(point: CGPoint, in size: CGSize, maxAngle: Double = 11) -> StickerTilt {
        guard size.width > 0, size.height > 0 else { return .resting }

        // Unit coordinates about the centre: -0.5 at one edge, +0.5 at the
        // other, clamped so an overshooting drag stops at the edge.
        let u = min(max(point.x / size.width, 0), 1) - 0.5
        let v = min(max(point.y / size.height, 0), 1) - 0.5

        return StickerTilt(
            // Pressing the top of a sticker pushes the top *away*, so the sign
            // is inverted against the vertical axis.
            pitch: -v * 2 * maxAngle,
            yaw: u * 2 * maxAngle,
            sheen: CGPoint(x: 0.5 - u, y: 0.5 - v)
        )
    }

    /// How far the cover sinks under the finger, as a scale factor. A sticker
    /// pressed into a surface gets slightly smaller; one that grew would read
    /// as a button lifting off.
    public static let pressedScale = 0.97
}
