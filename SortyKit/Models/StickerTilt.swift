import CoreGraphics
import Foundation

/// How a cover leans when a finger is on it.
///
/// The brief was that the cover should behave like a sticker: something
/// physical sitting on the surface that presses in under a fingertip, tips away
/// from it, and springs flat when released. That is a geometry problem rather
/// than a rendering one - where the finger is and how far the thing leans - so
/// it is resolved here where it can be asserted, and the view only applies the
/// numbers.
///
/// It used to carry a third number, the point the highlight travelled to. The
/// highlight was an overlay on Spotify's artwork and ADR-0012 removed it, so the
/// number went with it rather than staying as a value nothing reads.
public struct StickerTilt: Equatable, Sendable {
    /// Degrees about the horizontal axis. Positive tips the top away.
    public let pitch: Double
    /// Degrees about the vertical axis. Positive tips the right edge away.
    public let yaw: Double
    /// Flat. What Reduce Motion gets, and what a released cover springs back to.
    public static let resting = StickerTilt(pitch: 0, yaw: 0)

    public init(pitch: Double, yaw: Double) {
        self.pitch = pitch
        self.yaw = yaw
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
            yaw: u * 2 * maxAngle
        )
    }

    /// How far the cover sinks under the finger, as a scale factor. A sticker
    /// pressed into a surface gets slightly smaller; one that grew would read
    /// as a button lifting off.
    public static let pressedScale = 0.97
}
