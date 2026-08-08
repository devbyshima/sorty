import CoreGraphics
import Foundation
import Testing

/// Spotify offers each cover at 640, 300 and 64. The accessors used to pick
/// against a fixed floor written for a 44pt thumbnail, which handed a 300-pixel
/// file to a cover being drawn at 900 and made every large cover soft.
@Suite("Cover resolution")
struct CoverResolutionTests {

    private let spotifySizes = [
        SpotifyImage(url: "https://i.example/640.jpg", width: 640, height: 640),
        SpotifyImage(url: "https://i.example/300.jpg", width: 300, height: 300),
        SpotifyImage(url: "https://i.example/64.jpg", width: 64, height: 64),
    ]

    private func chosen(_ pixels: Int) -> String? {
        spotifySizes.url(coveringPixels: pixels)?.lastPathComponent
    }

    /// The bug, pinned: a 300pt cover on a 3x display needs 900 pixels.
    @Test("A large cover gets the largest file rather than a thumbnail")
    func largeCoverGetsLargeFile() {
        #expect(chosen(900) == "640.jpg")
        #expect(chosen(780) == "640.jpg")
    }

    /// Still the smallest that suffices. A list of 44pt thumbnails has no use
    /// for 640 pixels each, and would pay for every one.
    @Test("A thumbnail gets the smallest file that still covers it")
    func thumbnailGetsSmallFile() {
        #expect(chosen(64) == "64.jpg")
        #expect(chosen(132) == "300.jpg")
        #expect(chosen(300) == "300.jpg")
    }

    @Test("Exactly matching a size takes that size rather than the next one up")
    func exactMatchIsNotRoundedUp() {
        #expect(chosen(640) == "640.jpg")
    }

    @Test("Asking for more than exists gets the largest there is")
    func beyondTheLargestFallsBack() {
        #expect(chosen(4000) == "640.jpg")
    }

    @Test("No images resolves to nothing rather than a broken URL")
    func emptyResolvesToNil() {
        #expect([SpotifyImage]().url(coveringPixels: 300) == nil)
    }

    /// Spotify sometimes omits dimensions. A candidate that cannot be measured
    /// must not be silently dropped when it is all there is.
    @Test("Images with no declared width are still usable")
    func unsizedImagesStillResolve() {
        let unsized = [SpotifyImage(url: "https://i.example/x.jpg", width: nil, height: nil)]
        #expect(unsized.url(coveringPixels: 900)?.lastPathComponent == "x.jpg")
    }

    @Test("The demo catalogue offers the same three sizes, so it exercises the same path")
    func demoArtworkMatchesSpotify() {
        let images = DemoArtwork.images(seed: "album-1")
        #expect(images.compactMap(\.width).sorted() == [64, 300, 640])
        #expect(images.url(coveringPixels: 900) != nil)
    }
}

/// The cover leans like a sticker: pressed in where the finger lands, tipped
/// away from it, sprung flat on release. Geometry, so it is asserted here.
@Suite("Sticker tilt")
struct StickerTiltTests {

    private let size = CGSize(width: 300, height: 300)

    @Test("The centre is flat and lit from the middle")
    func centreIsResting() {
        let tilt = StickerTilt.at(point: CGPoint(x: 150, y: 150), in: size)
        #expect(abs(tilt.pitch) < 0.001)
        #expect(abs(tilt.yaw) < 0.001)
        #expect(abs(tilt.sheen.x - 0.5) < 0.001)
    }

    /// Pressing the top of a sticker pushes the top away, not towards you. The
    /// sign is the whole difference between "physical" and "wrong".
    @Test("Pressing the top tips the top away, and the bottom the other way")
    func verticalPressInverts() {
        let top = StickerTilt.at(point: CGPoint(x: 150, y: 0), in: size)
        let bottom = StickerTilt.at(point: CGPoint(x: 150, y: 300), in: size)
        #expect(top.pitch > 0)
        #expect(bottom.pitch < 0)
        #expect(abs(top.pitch) == abs(bottom.pitch))
    }

    @Test("Pressing the right tips the right edge away")
    func horizontalPress() {
        let right = StickerTilt.at(point: CGPoint(x: 300, y: 150), in: size)
        let left = StickerTilt.at(point: CGPoint(x: 0, y: 150), in: size)
        #expect(right.yaw > 0)
        #expect(left.yaw < 0)
    }

    /// The sheen stays where the light is while the surface turns under it, so
    /// it travels opposite the finger.
    @Test("The sheen moves opposite the touch")
    func sheenOpposesTheTouch() {
        let topLeft = StickerTilt.at(point: CGPoint(x: 0, y: 0), in: size)
        #expect(topLeft.sheen.x > 0.5)
        #expect(topLeft.sheen.y > 0.5)
    }

    /// A drag that continues past the edge must not wind up to an angle the
    /// finger never reached.
    @Test("A touch beyond the edge is clamped to the edge")
    func overshootIsClamped() {
        let edge = StickerTilt.at(point: CGPoint(x: 300, y: 150), in: size)
        let beyond = StickerTilt.at(point: CGPoint(x: 9000, y: 150), in: size)
        #expect(edge == beyond)
    }

    @Test("The lean never exceeds the maximum angle")
    func angleIsBounded() {
        for x in stride(from: -50.0, through: 350, by: 25) {
            for y in stride(from: -50.0, through: 350, by: 25) {
                let tilt = StickerTilt.at(point: CGPoint(x: x, y: y), in: size, maxAngle: 11)
                #expect(abs(tilt.pitch) <= 11.0001)
                #expect(abs(tilt.yaw) <= 11.0001)
            }
        }
    }

    /// A zero-sized view is a real state during layout, and dividing by it
    /// would produce a NaN rotation that SwiftUI renders as nothing at all.
    @Test("A zero-sized cover rests rather than producing NaN")
    func zeroSizeIsSafe() {
        #expect(StickerTilt.at(point: .zero, in: .zero) == .resting)
    }

    /// Pressed into the surface, not lifted off it.
    @Test("The press shrinks rather than grows")
    func pressSinks() {
        #expect(StickerTilt.pressedScale < 1)
        #expect(StickerTilt.pressedScale > 0.9)
    }
}
