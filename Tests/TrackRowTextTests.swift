import Foundation
import Testing

/// What a row says, in words. This lives in `SortifyKit` rather than the view
/// because every rule here is a rule worth asserting - and because the first
/// version of it, written inline in SwiftUI, shipped a row that printed the
/// position twice and read it aloud twice.
@Suite("Track row text")
struct TrackRowTextTests {

    private func row(
        index: Int = 0,
        title: String = "Winter Traffic",
        artist: String? = "Cassius Grey",
        tempo: Double? = 128,
        isEpisode: Bool = false
    ) -> TrackRow {
        let playable = Playable(
            id: "t\(index)",
            name: title,
            uri: isEpisode ? "spotify:episode:t\(index)" : "spotify:track:t\(index)",
            durationMS: 200_000,
            popularity: 50,
            artists: artist.map { [TrackArtist(name: $0)] },
            album: TrackAlbum(id: "a"),
            type: isEpisode ? .episode : .track
        )
        return TrackRow(
            originalIndex: index,
            playable: playable,
            features: tempo.map { AudioFeatures(id: "t\(index)", tempo: $0) }
        )
    }

    private func text(_ row: TrackRow, _ arrangement: Arrangement, position: Int = 1) -> TrackRowText {
        TrackRowText(row: row, position: position, arrangement: arrangement)
    }

    // MARK: - The value

    @Test("The value is the Attribute the Arrangement ranked by")
    func valueIsTheRankingAttribute() {
        #expect(text(row(), .attribute(.bpm, .descending)).value == "128")
    }

    /// The row already prints its position, title and artist. Showing them a
    /// second time in the value slot is noise, and the screen it produced had a
    /// grey 1 on the left and a green 1 on the right of every row.
    @Test("An Attribute the row already shows is not repeated in the value")
    func alreadyVisibleAttributesAreNotRepeated() {
        for attribute in [Attribute.order, .title, .artist] {
            let value = text(row(), .attribute(attribute, .ascending)).value
            #expect(value == nil, "\(attribute) is already on the row, but showed \(value ?? "nil") again")
        }
    }

    @Test("An Arrangement that ranks by no Attribute shows no value")
    func computedArrangementsShowNoValue() {
        for arrangement in [Arrangement.artistSeparation, .shuffle(seed: 1)] {
            #expect(text(row(), arrangement).value == nil)
        }
    }

    @Test("A track the provider had nothing for shows no value rather than a zero")
    func missingValueIsAbsentNotZero() {
        #expect(text(row(tempo: nil), .attribute(.bpm, .ascending)).value == nil)
    }

    // MARK: - Identity

    @Test("Title and artist are always present, whatever is applied")
    func identityIsNeverScrolledAway() {
        for arrangement in Arrangement.all {
            let text = text(row(), arrangement)
            #expect(text.title == "Winter Traffic")
            #expect(text.subtitle == "Cassius Grey")
            #expect(text.position == "1")
        }
    }

    @Test("An episode says so where the artist would be")
    func episodesAreDistinguishable() {
        let text = text(row(artist: nil, isEpisode: true), .originalOrder)
        #expect(text.subtitle == "Podcast episode")
    }

    @Test("A track with no artist is not left blank")
    func missingArtistHasAFallback() {
        #expect(text(row(artist: nil), .originalOrder).subtitle == "Unknown artist")
    }

    // MARK: - VoiceOver

    @Test("A row is spoken as one sentence: position, track, and the active value")
    func spokenAsOneSentence() {
        let spoken = text(row(), .attribute(.bpm, .descending), position: 4).spoken
        #expect(spoken == "4. Winter Traffic by Cassius Grey. BPM 128.")
    }

    /// The old table's row guarded this and the first list row lost the guard,
    /// which made VoiceOver say "1. Winter Traffic by Cassius Grey Original
    /// order 1".
    @Test("What the row already said is not said twice")
    func spokenLabelDoesNotRepeatItself() {
        for attribute in [Attribute.order, .title, .artist] {
            let spoken = text(row(), .attribute(attribute, .ascending)).spoken
            #expect(spoken == "1. Winter Traffic by Cassius Grey.", "repeated \(attribute): \(spoken)")
        }
    }

    @Test("An unavailable value is spoken as unavailable, never as nothing")
    func spokenLabelNamesMissingValues() {
        let spoken = text(row(tempo: nil), .attribute(.bpm, .ascending)).spoken
        #expect(spoken.contains("BPM unavailable"))
    }

    @Test("A computed Arrangement adds no value clause")
    func computedArrangementsSpeakNoValue() {
        #expect(text(row(), .artistSeparation).spoken == "1. Winter Traffic by Cassius Grey.")
    }
}
