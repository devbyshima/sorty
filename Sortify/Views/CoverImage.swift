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
                Rectangle().fill(SortifyTheme.surface)
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
                } else if url != nil {
                    ProgressView()
                }
            }
            .task(id: key) { await load(key) }
        }
    }

    private func load(_ key: LoadKey) async {
        // A recycled cell must not keep showing the previous row's cover while
        // the new one is still being drawn.
        if loadedFor?.url != key.url {
            image = nil
            loadedFor = nil
        }
        guard let url = key.url, key.pixels > 0 else { return }

        let resolved = await CoverImageLoader.shared.image(for: url, pixels: key.pixels)
        guard !Task.isCancelled else { return }
        image = resolved
        loadedFor = key
    }
}
