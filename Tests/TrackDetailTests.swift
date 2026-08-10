import Foundation
import Testing

/// The sheet is the half of the old table the list can't do - every Attribute
/// across one track. What it says is decided here, so it can be asserted here.
@Suite("Track detail")
struct TrackDetailTests {

    /// Three tracks spanning a known range, so a fraction can be checked at the
    /// bottom, the middle and the top rather than only for "not nil".
    private func rows(missingFeaturesAt missing: Set<Int> = []) -> [TrackRow] {
        (0..<3).map { index in
            TrackRow(
                originalIndex: index,
                playable: Playable(
                    id: "t\(index)",
                    name: "Track \(index)",
                    uri: "spotify:track:t\(index)",
                    durationMS: 200_000,
                    popularity: 50,
                    artists: [TrackArtist(name: "Artist \(index)")],
                    album: TrackAlbum(id: "alb", name: "The Album"),
                    type: .track
                ),
                addedAt: "2024-03-0\(index + 1)T00:00:00Z",
                features: missing.contains(index)
                    ? nil
                    : AudioFeatures(
                        id: "t\(index)",
                        tempo: Double(100 + index * 20),
                        energy: Double(index) / 2,
                        danceability: 0.5,
                        loudness: -7,
                        valence: 0.4,
                        acousticness: 0.2
                    ),
                albumReleaseDate: "2019-05-01"
            )
        }
    }

    private var episode: TrackRow {
        TrackRow(
            originalIndex: 3,
            playable: Playable(
                id: "e0",
                name: "Field Notes: Ep. 12",
                uri: "spotify:episode:e0",
                durationMS: 1_800_000,
                popularity: nil,
                artists: nil,
                album: nil,
                type: .episode
            )
        )
    }

    // MARK: - Composition

    @Test("Every Attribute appears, exactly once")
    func everyAttributeAppearsOnce() {
        let all = rows()
        let detail = TrackDetail(row: all[0], in: all)

        #expect(detail.readings.count == Attribute.allCases.count)
        #expect(Set(detail.readings.map(\.attribute)) == Set(Attribute.allCases))
    }

    /// The sheet's answer to a screen full of "Unavailable": the six that can be
    /// missing are gathered under a heading that says why, rather than scattered
    /// through the ones that never are.
    @Test("The sections split by where the values come from")
    func sectionsSplitByProvenance() {
        let all = rows()
        let detail = TrackDetail(row: all[0], in: all)

        #expect(detail.sections.count == 2)
        let features = detail.sections[0].readings.map(\.attribute)
        let metadata = detail.sections[1].readings.map(\.attribute)
        #expect(features == Attribute.allCases.filter(\.isAudioFeature))
        #expect(metadata == Attribute.allCases.filter { !$0.isAudioFeature })
        #expect(detail.sections[0].footer != nil, "the absences need their explanation")
    }

    @Test("Explanations come from the Attribute, not from a second wording")
    func explanationsShareOneSource() {
        let all = rows()
        let detail = TrackDetail(row: all[0], in: all)

        for reading in detail.readings {
            #expect(reading.explanation == reading.attribute.explanation)
        }
    }

    // MARK: - Identity

    @Test("The sheet identifies the track it opened")
    func identifiesTheTrack() {
        let all = rows()
        let detail = TrackDetail(row: all[1], in: all)

        #expect(detail.title == "Track 1")
        #expect(detail.subtitle == "Artist 1")
        #expect(detail.album == "The Album")
        // The **web** URL, not the `spotify:` URI it is built from. Opening a
        // custom scheme makes iOS interrupt with "Open in Spotify?", which is a
        // confirmation in front of a button that already said so; a universal
        // link goes straight there. This assertion is the rule, not a spelling.
        #expect(detail.spotifyURL == URL(string: "https://open.spotify.com/track/t1"))
    }

    /// The same words the row uses - opening a track must not rename it.
    @Test("An episode is named as one rather than given a blank artist")
    func episodeSubtitleMatchesTheRow() {
        let all = rows() + [episode]
        let detail = TrackDetail(row: episode, in: all)

        #expect(detail.subtitle == "Podcast episode")
        #expect(detail.subtitle == TrackRowText(row: episode, position: nil, arrangement: .originalOrder).subtitle)
        #expect(detail.album == nil, "an episode belongs to a show, not an album")
        #expect(detail.spotifyURL == URL(string: "https://open.spotify.com/episode/e0"))
    }

    @Test("A track with no URI offers no way out to Spotify")
    func noURIMeansNoLink() {
        let local = TrackRow(
            originalIndex: 0,
            playable: Playable(id: nil, name: "A local file", uri: nil, type: .track)
        )
        #expect(TrackDetail(row: local, in: [local]).spotifyURL == nil)
    }

    // MARK: - Unavailable, never zero

    @Test("A track the provider missed reads as unavailable")
    func missingFeaturesReadAsUnavailable() {
        let all = rows(missingFeaturesAt: [1])
        let detail = TrackDetail(row: all[1], in: all)

        for attribute in Attribute.allCases where attribute.isAudioFeature {
            guard let reading = detail.reading(for: attribute) else {
                Issue.record("\(attribute.name) is missing from the sheet")
                continue
            }
            #expect(reading.value == nil, "\(attribute.name)")
            #expect(reading.displayValue == "Unavailable", "\(attribute.name)")
            #expect(reading.isAvailable == false, "\(attribute.name)")
        }
    }

    /// The failure this guards against is silent: a `0` where nothing was
    /// measured is a number the listener cannot tell from a real one, and every
    /// audio feature has a legitimate zero.
    @Test("An absent measurement never renders as a number")
    func absentIsNeverZero() {
        let all = rows(missingFeaturesAt: [0])
        let detail = TrackDetail(row: all[0], in: all)

        for reading in detail.readings where !reading.isAvailable {
            #expect(Double(reading.displayValue) == nil, "\(reading.attribute.name)")
        }
    }

    /// `length` is the one audio feature with a fallback - Spotify supplies the
    /// duration whether or not the provider does - so it survives a miss while
    /// the rest don't.
    @Test("What Spotify supplies survives a provider miss")
    func spotifyMetadataSurvivesAMiss() {
        let all = rows(missingFeaturesAt: [0])
        let detail = TrackDetail(row: all[0], in: all)

        #expect(detail.reading(for: .length)?.value == "3:20")
        #expect(detail.reading(for: .pop)?.value == "50")
        #expect(detail.reading(for: .release)?.value == "2019-05-01")
        #expect(detail.reading(for: .title)?.value == "Track 0")
    }

    /// The footer explains the six absences above it. It must not also claim
    /// the section below never has any - an episode carries no artist, no
    /// popularity and no album to hold a release date, so four of those seven
    /// read "Unavailable" too, and a footer promising otherwise would be a
    /// sentence the very next screenful contradicts.
    @Test("The audio-features footer promises nothing about the section below")
    func footerDoesNotOverclaim() {
        let all = rows() + [episode]
        let detail = TrackDetail(row: episode, in: all)

        let absentBelow = detail.sections[1].readings.filter { !$0.isAvailable }
        #expect(!absentBelow.isEmpty, "an episode is exactly the case that would falsify it")

        let footer = detail.sections[0].footer ?? ""
        #expect(!footer.contains("never"))
    }

    @Test("An episode's popularity is unavailable rather than the least popular")
    func episodePopularityIsAbsent() {
        let all = rows() + [episode]
        let detail = TrackDetail(row: episode, in: all)

        #expect(detail.reading(for: .pop)?.value == nil)
        #expect(detail.reading(for: .artist)?.value == nil)
        #expect(detail.reading(for: .length)?.value == "30:00", "an episode still has a duration")
    }

    // MARK: - Bars

    @Test("A value sits where the playlist puts it - bottom, middle and top")
    func fractionsSpanTheRange() {
        let all = rows()

        #expect(TrackDetail(row: all[0], in: all).reading(for: .bpm)?.fraction == 0)
        #expect(TrackDetail(row: all[1], in: all).reading(for: .bpm)?.fraction == 0.5)
        #expect(TrackDetail(row: all[2], in: all).reading(for: .bpm)?.fraction == 1)
    }

    @Test("No value means no bar")
    func missingValuesDrawNoBar() {
        let all = rows(missingFeaturesAt: [1])
        let detail = TrackDetail(row: all[1], in: all)

        for reading in detail.readings where !reading.isAvailable {
            #expect(reading.fraction == nil, "\(reading.attribute.name)")
        }
    }

    /// Alphabetical order is a sequence, not a scale: "how far through the
    /// alphabet" measures nothing, so there is nothing for a bar to say.
    @Test("Title and artist have values but no bar")
    func unplottableAttributesDrawNoBar() {
        let all = rows()
        let detail = TrackDetail(row: all[0], in: all)

        for attribute in [Attribute.title, .artist] {
            #expect(detail.reading(for: attribute)?.value != nil, "\(attribute.name)")
            #expect(detail.reading(for: attribute)?.fraction == nil, "\(attribute.name)")
        }
    }

    /// The rows suppress this one - a bar for position down a list already in
    /// that order is a ramp that says nothing. Here the list is one track, and
    /// where it sat is exactly what a listener came to find out.
    @Test("Position gets a bar in the sheet even though the rows suppress it")
    func positionIsPlottedHere() {
        let all = rows()
        #expect(TrackDetail(row: all[2], in: all).reading(for: .order)?.value == "3")
        #expect(TrackDetail(row: all[2], in: all).reading(for: .order)?.fraction == 1)
    }

    /// A playlist where nothing varies has no ranking to draw. A full bar on
    /// every row would assert one nobody measured.
    @Test("A playlist with one value everywhere draws no bars")
    func degenerateRangeDrawsNoBar() {
        let flat = (0..<3).map { index in
            TrackRow(
                originalIndex: index,
                playable: Playable(id: "t\(index)", name: "Track \(index)", type: .track),
                features: AudioFeatures(id: "t\(index)", tempo: 120)
            )
        }
        let detail = TrackDetail(row: flat[0], in: flat)

        #expect(detail.reading(for: .bpm)?.value == "120", "the value is still real")
        #expect(detail.reading(for: .bpm)?.fraction == nil, "there is nothing to place it within")
    }

    @Test("A single-track playlist places nothing")
    func singleTrackDrawsNoBar() {
        let only = rows()[0]
        #expect(TrackDetail(row: only, in: [only]).reading(for: .bpm)?.fraction == nil)
    }
}

/// The sheet's contents come from the model, which decides what playlist a
/// track is being compared against.
@Suite("Track detail from the model")
@MainActor
struct TrackDetailModelTests {

    private func loadedModel(count: Int = 5) async -> TrackListModel {
        var table: [String: AudioFeatures] = [:]
        for index in 0..<count {
            table["t\(index)"] = AudioFeatures(id: "t\(index)", tempo: Double(100 + index * 10))
        }

        let model = TrackListModel(
            playlist: samplePlaylist(total: count),
            service: RecordingMusicService(items: sampleItems(count: count), albumsHaveDates: false),
            featureProvider: StubFeatureProvider(table: table),
            currentUserID: "me"
        )
        await model.load()
        return model
    }

    /// The same rule the row bars follow: a track the filter hid is still one of
    /// the others this track is being compared against, and letting the filter
    /// move the range would make the same track draw a different length
    /// depending on what else happened to be on screen.
    @Test("The range is the playlist's, not what the filter left")
    func filterDoesNotNarrowTheSheet() async {
        let model = await loadedModel()
        // Tempos are 100/110/120/130/140, and the track picked has to be one
        // whose fraction *would* move if the range narrowed. The minimum sits
        // at 0 against every range that contains it, so asserting on it passes
        // whether the invariant holds or not - the test would name the
        // regression without being able to see it. 110 reads 0.25 across the
        // whole playlist and 0.5 across the filtered 100–120.
        let row = model.rows[1]
        let unfiltered = model.detail(for: row).reading(for: .bpm)?.fraction
        #expect(unfiltered == 0.25)

        model.filter = BPMFilter(minBPM: 100, maxBPM: 120, includeDoubled: false)
        #expect(model.arrangedRows.count < model.rows.count, "the filter should hide something")
        #expect(model.detail(for: row).reading(for: .bpm)?.fraction == unfiltered)
    }

    /// A track only reachable past the group headers still opens to a full
    /// sheet - the Attributes it does have are exactly what says why it landed
    /// there.
    @Test("An unrankable track still has a sheet")
    func unrankableTracksOpenToo() async {
        let model = TrackListModel(
            playlist: samplePlaylist(total: 3),
            service: RecordingMusicService(items: sampleItems(count: 3), albumsHaveDates: false),
            featureProvider: StubFeatureProvider(table: [:]),
            currentUserID: "me"
        )
        await model.load()
        model.apply(.attribute(.bpm, .ascending))

        #expect(model.rankedRows.isEmpty, "nothing has a BPM to rank by")
        let detail = model.detail(for: model.arrangedRows[0])

        #expect(detail.reading(for: .bpm)?.isAvailable == false)
        #expect(detail.reading(for: .pop)?.isAvailable == true)
    }
}
