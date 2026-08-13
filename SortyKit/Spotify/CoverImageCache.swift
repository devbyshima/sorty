import CoreGraphics
import Foundation

/// Decoded cover artwork, held and readable *without* awaiting anything.
///
/// **The synchronous read is the whole reason this is not just a dictionary
/// inside `CoverImageLoader`.** An actor can only be asked with `await`, and
/// `CoverImage` asks from `.task(id:)`, which runs after the view has already
/// drawn once. So even with a perfect cache the first frame of every cover is
/// the placeholder, and the artwork replaces it a frame or two later - which is
/// invisible while scrolling and very visible at the moment a zoom is collapsing
/// into one of those covers. A cover the app already holds should be on screen
/// in the first frame that shows it, and that requires being able to ask a
/// question without suspending.
///
/// Bounded by bytes rather than by count: a 640x640 cover is about 1.6MB, so a
/// count-based limit generous enough to be useful is a memory problem, and one
/// small enough to be safe is uselessly small.
///
/// `@unchecked Sendable` with a stated invariant: **every access to `entries`,
/// `order` and `bytes` happens inside `lock`.** There is no other mutable state.
public final class CoverImageCache: @unchecked Sendable {
    public static let shared = CoverImageCache()

    private let lock = NSLock()
    private var entries: [URL: CGImage] = [:]
    private var order: [URL] = []
    private var bytes = 0
    private let byteBudget: Int

    /// 48MB holds roughly thirty full-size covers, or a great many thumbnails -
    /// comfortably more than a library screen and a playlist screen need at once,
    /// and small enough that it is not the reason this app is ever jettisoned.
    public init(byteBudget: Int = 48 * 1024 * 1024) {
        self.byteBudget = byteBudget
    }

    /// What the app already has, answered now.
    ///
    /// Does **not** promote the entry. A read this cheap is called from view
    /// bodies, which run for reasons that have nothing to do with what the
    /// listener is looking at, and letting those reorder the LRU would make the
    /// eviction order a function of SwiftUI's invalidation rather than of use.
    /// `store` does the promoting.
    public func image(for url: URL) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }
        return entries[url]
    }

    public func store(_ image: CGImage, for url: URL) {
        lock.lock()
        defer { lock.unlock() }

        if let existing = entries[url] {
            bytes -= Self.byteCost(existing)
        }
        entries[url] = image
        bytes += Self.byteCost(image)
        order.removeAll { $0 == url }
        order.append(url)

        while bytes > byteBudget, let oldest = order.first {
            order.removeFirst()
            if let dropped = entries.removeValue(forKey: oldest) {
                bytes -= Self.byteCost(dropped)
            }
        }
    }

    /// Test seams.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    public var byteCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return bytes
    }

    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
        order.removeAll()
        bytes = 0
    }

    /// What one decoded cover actually occupies. `bytesPerRow` rather than
    /// `width * 4`, because a decoder is free to pad each row.
    static func byteCost(_ image: CGImage) -> Int {
        max(image.bytesPerRow * image.height, 1)
    }
}
