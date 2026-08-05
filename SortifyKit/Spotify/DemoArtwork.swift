import CoreGraphics
import Foundation

/// Cover artwork for the demo catalogue, drawn on device.
///
/// Demo Mode runs with no account and no network (`CONTEXT.md`), so the covers
/// cannot be fetched. They still arrive the way real covers do — as URLs on the
/// model, at several sizes — so the model shape and `Playlist.cardImageURL`'s
/// size picking stay exactly what a signed-in listener exercises. Only the
/// final load branches, in `CoverImageLoader`.
///
/// Deterministic: the same seed always draws the same cover, so screenshots and
/// tests stay reproducible.
public enum DemoArtwork {
    public static let scheme = "sortify-demo"

    /// The URL a demo cover is addressed by. `size` is carried so the artwork
    /// behaves like Spotify's, which offers each cover at several resolutions.
    public static func url(seed: String, size: Int) -> String {
        "\(scheme)://cover/\(seed)?size=\(size)"
    }

    /// Spotify returns each cover at three sizes; mirroring that keeps
    /// `Playlist.cardImageURL`'s size-picking logic exercised in Demo Mode.
    public static func images(seed: String) -> [SpotifyImage] {
        [640, 300, 64].map {
            SpotifyImage(url: url(seed: seed, size: $0), width: $0, height: $0)
        }
    }

    /// A demo cover URL, taken apart. Nil for every URL that isn't one, which is
    /// how the image layer decides whether to draw or to fetch.
    ///
    /// Only the seed is carried. The `size` in the URL exists so the catalogue
    /// can offer a cover at several resolutions the way Spotify does — which is
    /// what `Playlist.cardImageURL` picks between — but a drawn cover is
    /// rendered to whatever the view actually needs, so the number in the URL
    /// never decides anything.
    public struct Request: Sendable, Hashable {
        public let seed: String

        public init?(url: URL) {
            guard url.scheme == DemoArtwork.scheme,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else { return nil }

            let seed = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !seed.isEmpty else { return nil }
            self.seed = seed
        }
    }

    // MARK: - Drawing

    /// The drawn pixels, for comparing two covers. Rendering goes through
    /// `cover(seed:size:)`; this exists because `CGImage` is not `Equatable`.
    public static func pixels(seed: String, size: Int) -> Data? {
        cover(seed: seed, size: size)?.dataProvider?.data.map { $0 as Data }
    }

    public static func cover(seed: String, size: Int) -> CGImage? {
        var generator = SplitMix64(seed: stableHash(seed))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Two nearby hues read as a deliberate palette; far-apart ones read as
        // two random colours fighting, so the spread stays inside an eighth of
        // the wheel.
        let baseHue = generator.nextDouble()
        let spread = 0.04 + generator.nextDouble() * 0.09
        let secondHue = (baseHue + spread).truncatingRemainder(dividingBy: 1)
        let dark = generator.nextDouble() < 0.5

        let top = rgb(hue: baseHue, saturation: 0.52 + generator.nextDouble() * 0.3,
                      brightness: dark ? 0.34 : 0.82)
        let bottom = rgb(hue: secondHue, saturation: 0.58 + generator.nextDouble() * 0.3,
                         brightness: dark ? 0.16 : 0.62)

        drawGradient(in: context, size: size, from: top, to: bottom, colorSpace: colorSpace)
        drawMotif(in: context, size: size, generator: &generator, dark: dark)

        return context.makeImage()
    }

    private static func drawGradient(
        in context: CGContext, size: Int,
        from top: (Double, Double, Double), to bottom: (Double, Double, Double),
        colorSpace: CGColorSpace
    ) {
        let components: [CGFloat] = [
            CGFloat(top.0), CGFloat(top.1), CGFloat(top.2), 1,
            CGFloat(bottom.0), CGFloat(bottom.1), CGFloat(bottom.2), 1,
        ]
        guard let gradient = CGGradient(
            colorSpace: colorSpace, colorComponents: components, locations: [0, 1], count: 2
        ) else { return }
        // The extend options matter: without them the gradient paints only the
        // band between its endpoints and leaves the far corner transparent.
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: size),
            end: CGPoint(x: size, y: 0),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    /// One of four geometric motifs. Enough variety that a screen of covers
    /// doesn't read as a repeated texture, few enough that they look like one
    /// design system.
    private static func drawMotif(
        in context: CGContext, size: Int, generator: inout SplitMix64, dark: Bool
    ) {
        let side = Double(size)
        let ink: CGFloat = dark ? 1 : 0
        context.setStrokeColor(red: ink, green: ink, blue: ink, alpha: 0.30)
        context.setFillColor(red: ink, green: ink, blue: ink, alpha: 0.22)
        context.setLineWidth(side * 0.012)

        switch generator.next(upperBound: 4) {
        case 0:
            // Concentric rings, off-centre.
            let cx = side * (0.3 + generator.nextDouble() * 0.4)
            let cy = side * (0.3 + generator.nextDouble() * 0.4)
            for ring in 1...5 {
                let r = side * 0.09 * Double(ring)
                context.strokeEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            }
        case 1:
            // Diagonal bars.
            let count = 4 + Int(generator.next(upperBound: 4))
            for bar in 0..<count {
                let offset = side * (Double(bar) / Double(count)) - side * 0.5
                context.move(to: CGPoint(x: offset, y: 0))
                context.addLine(to: CGPoint(x: offset + side, y: side))
            }
            context.strokePath()
        case 2:
            // A stack of horizon lines, like a waveform at rest.
            let count = 5 + Int(generator.next(upperBound: 5))
            for line in 0..<count {
                let y = side * (0.18 + 0.64 * (Double(line) / Double(max(1, count - 1))))
                let inset = side * generator.nextDouble() * 0.3
                context.move(to: CGPoint(x: inset, y: y))
                context.addLine(to: CGPoint(x: side - inset, y: y))
            }
            context.strokePath()
        default:
            // A single large disc, cropped by the frame.
            let r = side * (0.34 + generator.nextDouble() * 0.22)
            let cx = side * (0.25 + generator.nextDouble() * 0.5)
            let cy = side * (0.25 + generator.nextDouble() * 0.5)
            context.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        }
    }

    // MARK: - Helpers

    /// FNV-1a. `String.hashValue` is seeded per process, which would redraw
    /// every cover on each launch and break screenshot reproducibility.
    public static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    private static func rgb(hue: Double, saturation: Double, brightness: Double) -> (Double, Double, Double) {
        let h = (hue.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * 6
        let c = brightness * saturation
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - c
        let (r, g, b): (Double, Double, Double) = switch Int(h) {
        case 0: (c, x, 0)
        case 1: (x, c, 0)
        case 2: (0, c, x)
        case 3: (0, x, c)
        case 4: (x, 0, c)
        default: (c, 0, x)
        }
        return (r + m, g + m, b + m)
    }
}
