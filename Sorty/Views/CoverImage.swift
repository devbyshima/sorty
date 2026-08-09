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

            ZStack {
                Rectangle().fill(SortyTheme.surface)
                if let image, loadedFor?.url == url {
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
                    CoverRipple(phase: ripplePhase(for: url))
                        .transition(.opacity)
                }
            }
            .task(id: key) { await load(key) }
        }
    }

    /// A stable per-cover offset into the ripple, so a screen full of loading
    /// covers does not pulse in unison - which reads as an error state rather
    /// than as waiting. Derived from the URL so a given tile keeps its phase
    /// across a recycle instead of jumping when the cell is reused.
    private func ripplePhase(for url: URL?) -> Double {
        guard let url else { return 0 }
        return Double(abs(url.absoluteString.hashValue) % 1000) / 1000 * 6
    }

    private func load(_ key: LoadKey) async {
        // A recycled cell must not keep showing the previous row's cover while
        // the new one is still being drawn.
        if loadedFor?.url != key.url {
            image = nil
            loadedFor = nil
        }
        guard let url = key.url, key.pixels > 0 else { return }

        #if DEBUG
        // `-pendingCovers`: never resolve, so the ripple can be photographed.
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

/// What a cover looks like while its file is on the way: a slow ripple over the
/// empty tile, in place of a spinner.
///
/// > Important: this draws on the *placeholder*, never on artwork. Spotify's
/// > guidelines require artwork be "kept in its original form" with no
/// > animation, distortion, overlay or blur, so a shader over a loaded cover
/// > would be the prohibition itself rather than a near miss (ADR-0015).
/// > `CoverImage` swaps this out the moment the image resolves, and that
/// > ordering is the compliance boundary - not a detail of the transition.
///
/// Reduce Motion gets the same surface holding still. The ripple carries no
/// information the stillness doesn't; it is texture, and a listener who has
/// asked for less movement loses nothing by not seeing it.
struct CoverRipple: View {
    var phase: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// The two greys the ripple moves between.
    ///
    /// The separation is small but it cannot be *too* small, and the first
    /// attempt was: 0.925 against a pure-white `surface` is seven percent, which
    /// the falloff and the breath then cut to about three, and the shot came
    /// back looking like the shader had failed to load. These are wide enough to
    /// be seen and narrow enough that a grid of twenty waiting tiles still reads
    /// as one calm surface rather than as twenty things happening.
    private var low: Color { SortyTheme.surface }
    private var high: Color {
        colorScheme == .dark ? Color(white: 0.26) : Color(white: 0.87)
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Rectangle()
                .fill(low)
                .visualEffect { content, proxy in
                    content.colorEffect(
                        ShaderLibrary.coverRipple(
                            .float2(proxy.size),
                            .float(reduceMotion ? 0 : t),
                            .float(phase),
                            .color(low),
                            .color(high)
                        )
                    )
                }
        }
        .accessibilityHidden(true)
    }
}
