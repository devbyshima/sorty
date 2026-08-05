import CoreGraphics
import Foundation
import Testing

@Suite("Demo artwork")
struct DemoArtworkTests {

    @Test("A cover URL round-trips back to the seed that made it")
    func urlRoundTrips() {
        for size in [64, 300, 640] {
            let url = URL(string: DemoArtwork.url(seed: "demo-longrun", size: size))!
            #expect(DemoArtwork.Request(url: url)?.seed == "demo-longrun")
        }
    }

    @Test("A URL that isn't a demo cover is not claimed")
    func foreignURLsAreNotClaimed() {
        for string in [
            "https://i.scdn.co/image/ab67616d0000b273",
            "file:///tmp/cover.png",
            "spotify:track:abc",
        ] {
            #expect(DemoArtwork.Request(url: URL(string: string)!) == nil, "claimed \(string)")
        }
    }

    @Test("Spotify offers each cover at several sizes, and so does the demo catalogue")
    func offersMultipleSizes() {
        let images = DemoArtwork.images(seed: "demo-morning")
        #expect(images.count > 1)
        #expect(Set(images.map(\.width)).count == images.count, "sizes must differ")
        for image in images {
            #expect(image.width == image.height, "covers are square")
            #expect(DemoArtwork.Request(url: URL(string: image.url)!)?.seed == "demo-morning")
        }
    }

    @Test("The size picker resolves a demo playlist's cover")
    func cardImageURLResolves() {
        let playlist = Playlist(
            id: "p", name: "P", uri: "spotify:playlist:p",
            owner: PlaylistOwner(id: "demo-user"),
            images: DemoArtwork.images(seed: "p"),
            tracks: PlaylistTrackCount(total: 1)
        )
        let url = playlist.cardImageURL
        #expect(url != nil)
        #expect(DemoArtwork.Request(url: url!)?.seed == "p")
    }

    @Test("The same seed always draws the same cover, so screenshots are reproducible")
    func renderingIsDeterministic() {
        let first = DemoArtwork.pixels(seed: "demo-kitchen", size: 64)
        let second = DemoArtwork.pixels(seed: "demo-kitchen", size: 64)
        #expect(first != nil)
        #expect(first == second)
    }

    @Test("Different seeds draw different covers")
    func seedsDiffer() {
        let a = DemoArtwork.pixels(seed: "demo-kitchen", size: 64)
        let b = DemoArtwork.pixels(seed: "demo-longrun", size: 64)
        #expect(a != nil && b != nil)
        #expect(a != b)
    }

    @Test("The seed hash does not depend on the process, unlike String.hashValue")
    func hashIsStableAcrossProcesses() {
        #expect(DemoArtwork.stableHash("demo-longrun") == 11_588_260_115_634_792_616)
        #expect(DemoArtwork.stableHash("") == 14_695_981_039_346_656_037)
    }
}

@Suite("Cover image loader")
struct CoverImageLoaderTests {

    @Test("A demo cover is drawn rather than fetched, so Demo Mode stays offline")
    func drawsDemoCovers() async {
        let loader = CoverImageLoader()
        let url = URL(string: DemoArtwork.url(seed: "demo-morning", size: 300))!

        let image = await loader.image(for: url, pixels: 120)
        #expect(image != nil)
        #expect(image?.width == 120, "the cover is drawn at the size the view asked for")
    }

    @Test("Asking twice draws once")
    func cachesDrawnCovers() async {
        let loader = CoverImageLoader()
        let url = URL(string: DemoArtwork.url(seed: "demo-kitchen", size: 300))!

        _ = await loader.image(for: url, pixels: 64)
        _ = await loader.image(for: url, pixels: 64)
        #expect(await loader.cachedCount == 1)
    }

    @Test("Concurrent requests for one cover collapse into a single entry")
    func concurrentRequestsDoNotDuplicate() async {
        let loader = CoverImageLoader()
        let url = URL(string: DemoArtwork.url(seed: "demo-shared", size: 300))!

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask { _ = await loader.image(for: url, pixels: 48) }
            }
        }
        #expect(await loader.cachedCount == 1)
    }

    @Test("A long scroll cannot grow the cache without bound")
    func evictsBeyondTheLimit() async {
        let loader = CoverImageLoader(limit: 4)
        for index in 0..<10 {
            let url = URL(string: DemoArtwork.url(seed: "seed-\(index)", size: 300))!
            _ = await loader.image(for: url, pixels: 16)
        }
        #expect(await loader.cachedCount == 4)
    }

    @Test("A cover requested at two sizes is drawn at each, not upscaled from one")
    func sizeIsPartOfIdentity() async {
        let loader = CoverImageLoader()
        let url = URL(string: DemoArtwork.url(seed: "demo-latenight", size: 300))!

        let small = await loader.image(for: url, pixels: 32)
        let large = await loader.image(for: url, pixels: 96)
        #expect(small?.width == 32)
        #expect(large?.width == 96)
        #expect(await loader.cachedCount == 2)
    }
}
