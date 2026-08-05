import SwiftUI

/// Cover artwork, wherever it appears.
///
/// One view rather than a bare `AsyncImage` because demo covers are drawn on
/// device: a signed-in listener's covers are fetched, and Demo Mode has no
/// network (`CONTEXT.md`). `CoverImageLoader` decides which from the URL alone,
/// so everything here is plumbing — measure, ask, draw.
///
/// The size comes from the layout rather than from a caller's guess, because a
/// drawn cover is rendered at exactly the pixels it will occupy and a wrong
/// guess would upscale it.
struct CoverImage: View {
    let url: URL?

    @Environment(\.displayScale) private var displayScale
    @State private var image: CGImage?
    @State private var loadedFor: LoadKey?

    private struct LoadKey: Equatable {
        let url: URL?
        let pixels: Int
    }

    var body: some View {
        GeometryReader { proxy in
            let pixels = Int((max(proxy.size.width, proxy.size.height) * displayScale).rounded())
            let key = LoadKey(url: url, pixels: pixels)

            ZStack {
                Rectangle().fill(SortifyTheme.surface)
                if let image, loadedFor?.url == url {
                    Image(decorative: image, scale: 1)
                        .resizable()
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
