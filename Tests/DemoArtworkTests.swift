import CoreGraphics
import Foundation
import ImageIO
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

@Suite("Cover image cache")
struct CoverImageCacheTests {

    /// A drawn cover stands in for a fetched one: what is being tested is the
    /// bookkeeping, and the cache does not care where a `CGImage` came from.
    private func cover(_ seed: String, size: Int = 64) -> CGImage {
        DemoArtwork.cover(seed: seed, size: size)!
    }

    private func url(_ name: String) -> URL {
        URL(string: "https://i.scdn.co/image/\(name)")!
    }

    @Test("What the app already holds is answered without awaiting anything")
    func readsSynchronously() {
        let cache = CoverImageCache()
        let target = url("a")
        #expect(cache.image(for: target) == nil)

        cache.store(cover("a"), for: target)
        #expect(cache.image(for: target) != nil, "this is the read that beats the first frame")
    }

    @Test("The budget is bytes, and it is enforced")
    func evictsByBytes() {
        let one = CoverImageCache.byteCost(DemoArtwork.cover(seed: "size", size: 64)!)
        // Room for three, asked for five.
        let cache = CoverImageCache(byteBudget: one * 3)
        for index in 0..<5 {
            cache.store(cover("seed-\(index)"), for: url("seed-\(index)"))
        }
        #expect(cache.count == 3)
        #expect(cache.byteCount <= one * 3)
    }

    @Test("Eviction drops the least recently stored, not the most recent")
    func evictsOldestFirst() {
        let one = CoverImageCache.byteCost(DemoArtwork.cover(seed: "size", size: 64)!)
        let cache = CoverImageCache(byteBudget: one * 2)

        cache.store(cover("old"), for: url("old"))
        cache.store(cover("mid"), for: url("mid"))
        cache.store(cover("new"), for: url("new"))

        #expect(cache.image(for: url("old")) == nil, "the oldest goes first")
        #expect(cache.image(for: url("new")) != nil)
    }

    /// Reading must not promote, or the eviction order becomes a function of
    /// SwiftUI's invalidation rather than of what the listener is looking at -
    /// `CoverImage` reads this from its body, which runs for all sorts of
    /// reasons.
    @Test("Reading does not reorder the cache")
    func readingDoesNotPromote() {
        let one = CoverImageCache.byteCost(DemoArtwork.cover(seed: "size", size: 64)!)
        let cache = CoverImageCache(byteBudget: one * 2)

        cache.store(cover("first"), for: url("first"))
        cache.store(cover("second"), for: url("second"))
        _ = cache.image(for: url("first"))
        cache.store(cover("third"), for: url("third"))

        #expect(cache.image(for: url("first")) == nil, "a read must not have saved it")
    }

    @Test("Storing the same cover twice does not double-count its bytes")
    func replacingDoesNotLeakBudget() {
        let cache = CoverImageCache()
        let target = url("same")
        cache.store(cover("same"), for: target)
        let after = cache.byteCount
        cache.store(cover("same"), for: target)

        #expect(cache.count == 1)
        #expect(cache.byteCount == after)
    }
}

/// The fetched path, which the demo catalogue never exercises.
///
/// **This is the gap the bug lived in.** Demo covers are drawn and were always
/// cached, so every screenshot, every harness run and every test went down the
/// `drawn` branch - while a signed-in listener, whose covers are fetched, got a
/// fresh `CGImageSourceCreateImageAtIndex` on every appearance of every cover.
/// A `file:` URL is enough to take the other branch for real.
@Suite("Fetched covers are cached")
struct FetchedCoverTests {

    private func writePNG(_ seed: String) throws -> URL {
        let image = DemoArtwork.cover(seed: seed, size: 64)!
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sorty-\(seed)-\(UUID().uuidString).png")
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL, "public.png" as CFString, 1, nil
        )!
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    @Test("A fetched cover is decoded once and then held")
    func fetchedCoversAreCached() async throws {
        CoverImageCache.shared.removeAll()
        let file = try writePNG("fetched-once")
        defer { try? FileManager.default.removeItem(at: file) }

        let loader = CoverImageLoader()
        let first = await loader.image(for: file, pixels: 64)
        #expect(first != nil, "the file: branch really is the fetch path")
        #expect(CoverImageCache.shared.image(for: file) != nil)

        // The second ask must be answerable without touching the file at all -
        // which is what returning from a playlist does, for every visible cover.
        try? FileManager.default.removeItem(at: file)
        let second = await loader.image(for: file, pixels: 64)
        #expect(second != nil, "a deleted file proves the answer came from the cache")
    }

    @Test("A held cover is readable before any await, which is what beats the first frame")
    func heldCoverIsReadableSynchronously() async throws {
        CoverImageCache.shared.removeAll()
        let file = try writePNG("fetched-sync")
        defer { try? FileManager.default.removeItem(at: file) }

        _ = await CoverImageLoader().image(for: file, pixels: 64)
        #expect(CoverImageCache.shared.image(for: file) != nil)
    }
}
