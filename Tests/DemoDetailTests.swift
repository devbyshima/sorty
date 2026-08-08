import Foundation
import Testing

/// Diagnostic for a reported bug: Release date and Popularity read "Unavailable"
/// for every track in the detail sheet.
///
/// Both are Spotify's own metadata rather than Audio features, so the sheet
/// groups them under a heading that promises they are the values that *don't*
/// go missing. If they are absent the heading is lying, which is worse than the
/// absence.
@Suite("Demo Mode track detail")
@MainActor
struct DemoDetailTests {

    private func loadedModel() async -> TrackListModel {
        let catalog = DemoCatalog()
        let model = TrackListModel(
            playlist: catalog.playlists[0],
            service: DemoMusicService(catalog: catalog, pageDelay: .zero),
            featureProvider: StubFeatureProvider(),
            currentUserID: "demo-user"
        )
        await model.load()
        return model
    }

    @Test("Every demo track carries a popularity")
    func popularityIsPresent() async {
        let model = await loadedModel()
        let tracks = model.rows.filter { !$0.playable.isEpisode }
        #expect(!tracks.isEmpty)

        for row in tracks {
            let detail = TrackDetail(row: row, in: model.rows)
            #expect(
                detail.reading(for: .pop)?.isAvailable == true,
                "popularity unavailable for \(row.playable.name)"
            )
        }
    }

    @Test("Every demo track carries a release date")
    func releaseDateIsPresent() async {
        let model = await loadedModel()
        let tracks = model.rows.filter { !$0.playable.isEpisode }
        #expect(!tracks.isEmpty)

        for row in tracks {
            let detail = TrackDetail(row: row, in: model.rows)
            #expect(
                detail.reading(for: .release)?.isAvailable == true,
                "release date unavailable for \(row.playable.name)"
            )
        }
    }
}
