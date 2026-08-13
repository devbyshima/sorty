import CoreGraphics
import Foundation
import ImageIO

/// Resolves cover artwork from a URL, whoever the listener is.
///
/// Demo covers are drawn on device and real ones are fetched, and the URL alone
/// decides which - `DemoArtwork.Request` claims a demo cover and nothing else.
/// Keeping that decision here rather than in the view is what makes it
/// testable: `SortyKit` is what the test target compiles.
///
/// Returns `CGImage` rather than a SwiftUI `Image` so nothing about the
/// rendering framework leaks into the kit.
public actor CoverImageLoader {
    public static let shared = CoverImageLoader()

    /// Drawn covers, held because they cost real CPU, a scrolling list asks for
    /// the same one repeatedly, and there are as many as there are demo albums.
    private var drawn: [Key: CGImage] = [:]
    private var inFlight: [Key: Task<CGImage?, Never>] = [:]
    private var recentlyUsed: [Key] = []

    /// Decoded fetched covers live in `CoverImageCache`, not here.
    ///
    /// **They used to live nowhere, and that was the bug.** The reasoning was
    /// that `URLSession` already caches the bytes and a second cache of decoded
    /// images "would grow with the size of the listener's library" - true of an
    /// unbounded one, and the conclusion drawn from it was that there should be
    /// none. So every appearance of every cover ran a fresh
    /// `CGImageSourceCreateImageAtIndex`: not just the first sight of it, but
    /// every scroll back up, and every return from a playlist.
    ///
    /// It sits outside this actor because the fix needs a *synchronous* read -
    /// see `CoverImageCache`.

    /// A drawn cover is rendered to fit, so its size is part of its identity.
    private struct Key: Hashable {
        let seed: String
        let pixels: Int
    }

    /// Distinct covers a session realistically shows, with room for two size
    /// classes of each. Past this the least recently used are dropped, so a long
    /// scroll cannot grow the cache without bound.
    private let limit: Int

    public init(limit: Int = 240) {
        self.limit = limit
    }

    public func image(for url: URL, pixels: Int) async -> CGImage? {
        #if !DEBUG
        // No demo covers exist in a shipped build, so nothing can produce a URL
        // this branch would claim. Compiling the generator in anyway would be
        // shipping a demo path that only dead code can reach - see ADR-0007.
        return await fetchCached(url)
        #else
        guard let request = DemoArtwork.Request(url: url) else {
            return await fetchCached(url)
        }

        let key = Key(seed: request.seed, pixels: max(pixels, 1))
        if let hit = drawn[key] {
            touch(key)
            return hit
        }
        if let running = inFlight[key] { return await running.value }

        // Drawing is CPU work; keep it off the actor and off the main thread.
        let task = Task.detached(priority: .userInitiated) {
            DemoArtwork.cover(seed: key.seed, size: key.pixels)
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil

        if let result {
            drawn[key] = result
            touch(key)
            evictIfNeeded()
        }
        return result
        #endif
    }

    private func touch(_ key: Key) {
        recentlyUsed.removeAll { $0 == key }
        recentlyUsed.append(key)
    }

    private func evictIfNeeded() {
        while recentlyUsed.count > limit {
            drawn.removeValue(forKey: recentlyUsed.removeFirst())
        }
    }

    /// Test seam: how many covers are currently held.
    public var cachedCount: Int { drawn.count }

    /// A fetch that remembers what it decoded.
    ///
    /// The in-flight table is shared with the drawn path on purpose: a library
    /// screen and a playlist screen can ask for the same cover in the same
    /// frame, and without it they would each pay for a decode.
    private func fetchCached(_ url: URL) async -> CGImage? {
        if let hit = CoverImageCache.shared.image(for: url) { return hit }

        let key = Key(seed: url.absoluteString, pixels: 0)
        if let running = inFlight[key] { return await running.value }

        let task = Task.detached(priority: .userInitiated) { await Self.fetch(url) }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil

        if let result { CoverImageCache.shared.store(result, for: url) }
        return result
    }

    private static func fetch(_ url: URL) async -> CGImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0
        else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
