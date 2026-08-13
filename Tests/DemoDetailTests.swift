import Foundation
import Testing

/// Diagnostic for a reported bug: Release date read "Unavailable" for every
/// track in the detail sheet.
///
/// It is Spotify's own metadata rather than an Audio feature, so the sheet
/// groups it under a heading that promises these are the values that *don't* go
/// missing. If it is absent the heading is lying, which is worse than the
/// absence.
///
/// Popularity was the other half of that bug and is gone: ADR-0026 removed it,
/// because unlike a release date there was no second place to read it from.
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
