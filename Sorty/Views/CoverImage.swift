import SwiftUI

/// Cover artwork, wherever it appears.
///
/// One view rather than a bare `AsyncImage` because demo covers are drawn on
/// device: a signed-in listener's covers are fetched, and Demo Mode has no
/// network (`CONTEXT.md`). `CoverImageLoader` decides which from the URL alone,
/// so everything here is plumbing: measure, ask, draw.
///
/// **The size comes from the layout, and so does the file.** Spotify offers each
/// cover at 640, 300 and 64, and the old accessors picked against a fixed floor
/// written for a 44pt thumbnail. That silently handed a 300-pixel file to a
/// 300pt cover on a 3x display, which needs 900 - the artwork was soft
/// everywhere it had been made large. Measuring first and *then* choosing the
/// file is the only version that stays correct when a layout changes.
struct CoverImage: View {
    /// Every size the cover comes in. The one that gets fetched is chosen once
    /// the view knows how many pixels it occupies.
    let images: [SpotifyImage]

    @Environment(\.displayScale) private var displayScale
    @State private var image: CGImage?
    @State private var loadedFor: LoadKey?

    init(images: [SpotifyImage]) {
        self.images = images
    }

    /// For the one caller that has a resolved URL rather than candidates.
    init(url: URL?) {
        self.images = url.map { [SpotifyImage(url: $0.absoluteString, width: nil, height: nil)] } ?? []
    }

    private struct LoadKey: Equatable {
        let url: URL?
        let pixels: Int
    }

    var body: some View {
        GeometryReader { proxy in
            let pixels = Int((max(proxy.size.width, proxy.size.height) * displayScale).rounded())
            let url = images.url(coveringPixels: pixels)
            let key = LoadKey(url: url, pixels: pixels)

            // **Warm covers are drawn on the first frame, not the second.**
            //
            // `image` is `@State`, and `load` runs from `.task(id:)` - which is
            // after this view has already rendered once. So a cover the app was
            // holding all along still showed its placeholder for a frame or two
            // before the artwork replaced it, and `wasWaited` correctly refused
            // to fade a wait that short. Scrolling hides that; collapsing a zoom
            // *into* one of those covers does not, and it is what made coming
            // back from a playlist snap.
            //
            // Reading the cache here costs a lock and a dictionary lookup, and
            // it is the only way to answer before the first frame: `load` cannot
            // help, because reaching an actor means suspending, and suspending
            // means the frame has already gone out.
            let warm = url.flatMap { CoverImageCache.shared.image(for: $0) }
            let shown = (image != nil && loadedFor?.url == url) ? image : warm

            ZStack {
                Rectangle().fill(SortyTheme.surface)
                if let image = shown {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        // Both of these matter and neither is the default.
                        //
                        // Spotify's largest cover is 640 pixels, and a 260pt
                        // cover on a 3x display asks for 780, so the big covers
                        // are *always* being scaled up: there is no larger file
                        // to fetch. `resizable()` alone leaves the quality to a
                        // default that is tuned for speed, which is what made
                        // them read as soft. High interpolation is the whole
                        // difference on an upscale, and antialiasing keeps the
                        // rounded corner clean rather than stepped.
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFill()
                        // Both branches carry it, or the placeholder vanishes on
                        // the first frame while the artwork is still fading in
                        // behind it. Whether this plays at all is decided in
                        // `load`, not here.
                        .transition(.opacity)
                } else if url != nil {
                    CoverShimmer(phase: shimmerPhase(for: url))
                        .transition(.opacity)
                }
            }
            .task(id: key) { await load(key) }
        }
    }

    /// A stable per-cover offset into the sweep, so a screen full of loading
    /// covers does not shimmer in unison - which reads as an error state rather
    /// than as waiting. Derived from the URL so a given tile keeps its phase
    /// across a recycle instead of jumping when the cell is reused.
    ///
    /// Spread over the shader's own 2.2s cycle rather than the ripple's 6, or
    /// every tile lands within the same two passes and the grid sweeps as one
    /// sheet - the exact thing the offset exists to prevent.
    private func shimmerPhase(for url: URL?) -> Double {
        guard let url else { return 0 }
        return Double(abs(url.absoluteString.hashValue) % 1000) / 1000 * 2.2
    }

    private func load(_ key: LoadKey) async {
        // A recycled cell must not keep showing the previous row's cover while
        // the new one is still being drawn.
        if loadedFor?.url != key.url {
            image = nil
            loadedFor = nil
        }
        guard let url = key.url, key.pixels > 0 else { return }

        // Already held, and already on screen: the body read it synchronously
        // before this ran. Adopting it into state costs nothing and skips an
        // actor hop that every visible cover would otherwise pay on every
        // appearance - which, on a library of forty playlists, is forty of them
        // each time the listener comes back from a playlist.
        if let held = CoverImageCache.shared.image(for: url) {
            image = held
            loadedFor = key
            return
        }

        #if DEBUG
        // `-pendingCovers`: never resolve, so the shimmer can be photographed.
        // No-op in a shipping build, where `holdsCovers` is a constant false.
        if DebugLaunch.holdsCovers { return }
        #endif

        let started = ContinuousClock.now
        let resolved = await CoverImageLoader.shared.image(for: url, pixels: key.pixels)
        guard !Task.isCancelled else { return }

        // Only a wait somebody saw is worth bridging.
        //
        // `CoverImageLoader` deliberately holds no decoded fetched covers, so a
        // recycled cell re-resolves from the byte cache in a frame or two.
        // Fading *that* would make the whole library shimmer every time it
        // scrolled, which is worse than the pop this is here to remove. Below
        // the threshold the spinner never really registered and the artwork
        // should simply be there.
        let wasWaited = ContinuousClock.now - started > .milliseconds(100)

        if wasWaited {
            withAnimation(.easeOut(duration: 0.18)) {
                image = resolved
                loadedFor = key
            }
        } else {
            image = resolved
            loadedFor = key
        }
    }
}

/// What a cover looks like while its file is on the way: a slow shimmer across
/// the empty tile, in place of a spinner.
///
/// > Important: this draws on the *placeholder*, never on artwork. Spotify's
/// > guidelines require artwork be "kept in its original form" with no
/// > animation, distortion, overlay or blur, so a shader over a loaded cover
/// > would be the prohibition itself rather than a near miss (ADR-0015).
/// > `CoverImage` swaps this out the moment the image resolves, and that
/// > ordering is the compliance boundary - not a detail of the transition.
/// > The change from a ripple to a sweep (ADR-0020) does not move that boundary
/// > an inch: it is the same surface, drawn differently.
///
/// Reduce Motion gets the same surface holding still, at the shader's resting
/// value rather than frozen mid-sweep. The shimmer carries no information the
/// stillness doesn't; it is texture, and a listener who has asked for less
/// movement loses nothing by not seeing it.
struct CoverShimmer: View {
    var phase: Double = 0

    /// The shader's own sweep period, in seconds, so the placeholders can spread
    /// their phases across exactly one cycle.
    ///
    /// Read from `SkeletonPlan`, which is where the number lives so that it can
    /// be tested. It must also equal the `cycle` constant in `Shaders.metal`,
    /// and that pair is kept by hand because a shader cannot import Swift.
    static var cycle: Double { SkeletonPlan.period }

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var reduceMotion: Bool { Motion.isReduced(systemReduceMotion) }

    /// **`Skeleton`'s own pair, not a private one.** A cover placeholder and the
    /// bars beneath it are the same material, and the only way to keep that true
    /// is for there to be one definition of the material. This view held a second
    /// copy for exactly one day and the two had already drifted: the cover was
    /// white where the bars were `raisedSurface`, so the invariant ADR-0019
    /// states was false in the shipped pixels.
    var body: some View {
        // Resolved once per body evaluation, never inside the per-frame closure.
        // See the note in `SkeletonShape`: these tokens allocate a fresh dynamic
        // `UIColor` on every access, and reaching for them each frame was
        // measurable as dropped frames.
        let base = Skeleton.base
        let highlight = Skeleton.highlight(colorScheme)

        return ShimmerDriver(reduceMotion: reduceMotion) { time, motion in
            if let motion {
                tile(time: time, motion: motion, base: base, highlight: highlight)
            } else {
                Rectangle().fill(base)
            }
        }
        .accessibilityHidden(true)
    }

    /// One frame of the sweep, shared by both branches so they cannot drift.
    private func tile(time: Double, motion: Float, base: Color, highlight: Color) -> some View {
        Rectangle()
            .fill(base)
            .visualEffect { content, proxy in
                content.colorEffect(
                    ShaderLibrary.coverShimmer(
                        .float2(proxy.size),
                        .float(time),
                        .float(phase),
                        .float(motion),
                        .color(base),
                        .color(highlight)
                    )
                )
            }
    }
}
