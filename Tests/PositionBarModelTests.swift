import Foundation
import Testing

/// Whether a bar belongs at all is a decision, not a layout detail, so it is
/// made here rather than in the view.
@Suite("Position bars on the list")
@MainActor
struct PositionBarModelTests {

    private func features(count: Int) -> [String: AudioFeatures] {
        var table: [String: AudioFeatures] = [:]
        for index in 0..<count {
            table["t\(index)"] = AudioFeatures(
                id: "t\(index)", tempo: Double(100 + index * 10), energy: Double(index) / Double(count)
            )
        }
        return table
    }

    private func loadedModel(count: Int = 5) async -> TrackListModel {
        let model = TrackListModel(
            playlist: Playlist(
                id: "p", name: "P", uri: "spotify:playlist:p",
                owner: PlaylistOwner(id: "me"), tracks: PlaylistTrackCount(total: count)
            ),
            service: RecordingMusicService(items: sampleItems(count: count), albumsHaveDates: false),
            featureProvider: StubFeatureProvider(table: features(count: count)),
            currentUserID: "me"
        )
        await model.load()
        return model
    }

    @Test("An Attribute-derived Arrangement gets a range")
    func attributeArrangementsHaveARange() async {
        let model = await loadedModel()
        model.apply(.attribute(.bpm, .descending))

        #expect(model.positionRange?.attribute == .bpm)
        #expect(model.positionRange?.minimum == 100)
        #expect(model.positionRange?.maximum == 140)
    }

    @Test("Artist separation and Shuffle get none — they rank by no Attribute")
    func computedArrangementsHaveNoRange() async {
        let model = await loadedModel()
        for arrangement in [Arrangement.artistSeparation, .shuffled] {
            model.apply(arrangement)
            #expect(model.positionRange == nil, "\(arrangement.name)")
        }
    }

    /// The row already prints its position, title and artist, so ticket 03
    /// suppresses repeating them as a value. A bar under a value that isn't
    /// there would be a bar under nothing — and a bar for position is a ramp
    /// from empty to full down a list that is already in that order.
    @Test("Attributes the row already shows get no bar")
    func alreadyVisibleAttributesGetNoBar() async {
        let model = await loadedModel()
        for attribute in [Attribute.order, .title, .artist] {
            model.apply(.attribute(attribute, .ascending))
            #expect(model.positionRange == nil, "\(attribute)")
        }
    }

    @Test("The range comes from the loaded playlist, not from what the filter left")
    func filterDoesNotNarrowTheRange() async {
        let model = await loadedModel()
        model.apply(.attribute(.bpm, .ascending))
        let unfiltered = model.positionRange

        model.filter = BPMFilter(minBPM: 120, maxBPM: 130, includeDoubled: false)
        #expect(model.arrangedRows.count < model.rows.count, "the filter should hide something")
        #expect(
            model.positionRange == unfiltered,
            "a hidden track is still part of the playlist the bar compares against"
        )
    }

    @Test("A playlist whose provider returned nothing shows no bars")
    func noFeaturesMeansNoBars() async {
        let model = TrackListModel(
            playlist: Playlist(
                id: "p", name: "P", uri: "spotify:playlist:p",
                owner: PlaylistOwner(id: "me"), tracks: PlaylistTrackCount(total: 3)
            ),
            service: RecordingMusicService(items: sampleItems(count: 3), albumsHaveDates: false),
            featureProvider: StubFeatureProvider(table: [:]),
            currentUserID: "me"
        )
        await model.load()
        model.apply(.attribute(.bpm, .ascending))

        #expect(model.positionRange == nil)
    }
}
