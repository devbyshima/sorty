import Foundation
import Testing

/// The bar's whole claim is "here is where this track sits among the others",
/// so the arithmetic behind it has to be right at the ends, right in the
/// middle, and honest when there is nothing to compare.
@Suite("Attribute range")
struct AttributeRangeTests {

    private func rows(_ tempos: [Double?]) -> [TrackRow] {
        tempos.enumerated().map { index, tempo in
            TrackRow(
                originalIndex: index,
                playable: Playable(
                    id: "t\(index)", name: "Track \(index)", uri: "spotify:track:t\(index)",
                    artists: [TrackArtist(name: "A")], album: TrackAlbum(id: "a"), type: .track
                ),
                features: tempo.map { AudioFeatures(id: "t\(index)", tempo: $0) }
            )
        }
    }

    // MARK: - Resolution

    @Test("The range spans the values actually present")
    func rangeSpansTheValues() {
        let range = AttributeRange(attribute: .bpm, rows: rows([90, 150, 120]))
        #expect(range?.minimum == 90)
        #expect(range?.maximum == 150)
    }

    @Test("The range is this playlist's, not a theoretical scale")
    func rangeIsLocalNotGlobal() {
        // Every track is fast. A 0–200 BPM scale would bunch them all at the
        // top and show no variation; the playlist's own range separates them.
        let range = AttributeRange(attribute: .bpm, rows: rows([170, 175, 180]))
        #expect(range?.minimum == 170)
        #expect(range?.maximum == 180)
        #expect(range?.fraction(for: rows([170, 175, 180])[1]) == 0.5)
    }

    @Test("Tracks with no value do not widen the range")
    func missingValuesAreIgnored() {
        let range = AttributeRange(attribute: .bpm, rows: rows([100, nil, 140, nil]))
        #expect(range?.minimum == 100)
        #expect(range?.maximum == 140)
    }

    @Test("A playlist where nothing has a value has no range at all")
    func noValuesMeansNoRange() {
        #expect(AttributeRange(attribute: .bpm, rows: rows([nil, nil])) == nil)
        #expect(AttributeRange(attribute: .bpm, rows: []) == nil)
    }

    /// Alphabetical order is a sequence, not a scale: "how far through the
    /// alphabet" measures nothing, so there is no line for a title to sit on.
    @Test("Title and artist have no range - there is no line to sit on")
    func alphabeticalAttributesHaveNoRange() {
        for attribute in [Attribute.title, .artist] {
            #expect(AttributeRange(attribute: attribute, rows: rows([100, 140])) == nil, "\(attribute)")
        }
    }

    /// A date sorts as text but is genuinely earlier or later, so "released
    /// halfway through this playlist's span" means something.
    @Test("Dates do have a range, even though they compare as text")
    func datesHaveARange() {
        let tracks = ["2020-01-01", "2020-01-11", "2020-01-21"].enumerated().map { index, date in
            TrackRow(
                originalIndex: index,
                playable: Playable(id: "t\(index)", name: "T", uri: "spotify:track:t\(index)", type: .track),
                albumReleaseDate: date
            )
        }
        let range = AttributeRange(attribute: .release, rows: tracks)
        #expect(range != nil)
        #expect(range?.fraction(for: tracks[0]) == 0)
        #expect(range?.fraction(for: tracks[1]) == 0.5)
        #expect(range?.fraction(for: tracks[2]) == 1)
    }

    @Test("Spotify's partial release dates are placed at the start of the period")
    func partialDatesResolve() {
        #expect(TrackRow.dayCount(fromISODate: "2020") == TrackRow.dayCount(fromISODate: "2020-01-01"))
        #expect(TrackRow.dayCount(fromISODate: "2020-03") == TrackRow.dayCount(fromISODate: "2020-03-01"))
        #expect(TrackRow.dayCount(fromISODate: "not-a-date") == nil)
    }

    /// Popularity used to coerce a missing value to zero, which made an episode
    /// the least popular track in the playlist and drew it a bar.
    @Test("A track with no popularity has none, rather than zero")
    func missingPopularityIsAbsent() {
        let episode = TrackRow(
            originalIndex: 0,
            playable: Playable(id: "e", name: "Ep", uri: "spotify:episode:e", popularity: nil, type: .episode)
        )
        #expect(episode.numericValue(for: .pop) == nil)
        #expect(episode.plottableValue(for: .pop) == nil)
    }

    // MARK: - Fraction

    @Test("Fraction is 0 at the minimum, 1 at the maximum and 0.5 at the midpoint")
    func fractionAtTheEndsAndMiddle() {
        let tracks = rows([100, 200, 150])
        let range = AttributeRange(attribute: .bpm, rows: tracks)

        #expect(range?.fraction(for: tracks[0]) == 0)
        #expect(range?.fraction(for: tracks[1]) == 1)
        #expect(range?.fraction(for: tracks[2]) == 0.5)
    }

    @Test("A track with no value has no fraction - an absent measurement is not a low one")
    func missingValueHasNoFraction() {
        let tracks = rows([100, nil, 200])
        let range = AttributeRange(attribute: .bpm, rows: tracks)
        #expect(range?.fraction(for: tracks[1]) == nil)
    }

    @Test("Negative scales work - loudness is decibels below zero")
    func negativeValuesFraction() {
        let tracks = [-20.0, -4.0, -12.0].enumerated().map { index, loudness in
            TrackRow(
                originalIndex: index,
                playable: Playable(id: "t\(index)", name: "T", uri: "spotify:track:t\(index)", type: .track),
                features: AudioFeatures(id: "t\(index)", loudness: loudness)
            )
        }
        let range = AttributeRange(attribute: .loud, rows: tracks)
        #expect(range?.minimum == -20)
        #expect(range?.maximum == -4)
        #expect(range?.fraction(for: tracks[2]) == 0.5)
    }

    // MARK: - Degenerate

    /// When every track scores the same, no track is higher than another. A
    /// full bar on each asserts "top of the range" and an empty one asserts the
    /// opposite; both claim a ranking nobody measured. Absence is the same
    /// honesty already applied to a missing value, and it keeps a single-track
    /// playlist from showing a maxed-out bar on every Attribute in ticket 06's
    /// sheet.
    @Test("When every track is identical, no bar is drawn")
    func identicalValuesDrawNoBar() {
        let tracks = rows([120, 120, 120])
        let range = AttributeRange(attribute: .bpm, rows: tracks)

        #expect(range?.minimum == 120)
        #expect(range?.maximum == 120)
        #expect(range?.isDegenerate == true)
        for track in tracks {
            #expect(range?.fraction(for: track) == nil)
        }
    }

    @Test("A single track has nothing to be compared against")
    func singleTrack() {
        let tracks = rows([137])
        let range = AttributeRange(attribute: .bpm, rows: tracks)
        #expect(range?.isDegenerate == true)
        #expect(range?.fraction(for: tracks[0]) == nil)
    }

    @Test("A value from outside the range is clamped rather than overflowing the bar")
    func outOfRangeValuesAreClamped() {
        // Ticket 06's sheet draws a track against a range resolved elsewhere,
        // so a value beyond either end has to stay drawable.
        let range = AttributeRange(attribute: .bpm, rows: rows([100, 200]))
        let tooFast = rows([260])[0]
        let tooSlow = rows([40])[0]

        #expect(range?.fraction(for: tooFast) == 1)
        #expect(range?.fraction(for: tooSlow) == 0)
    }
}
