import Foundation
import Testing

// MARK: - Fixtures

private func makeRow(
    index: Int,
    title: String = "Track",
    artist: String? = "Artist",
    durationMS: Int? = 200_000,
    popularity: Int? = 50,
    tempo: Double? = 120,
    energy: Double? = 0.5,
    danceability: Double? = 0.5,
    loudness: Double? = -8,
    valence: Double? = 0.5,
    acousticness: Double? = 0.5,
    releaseDate: String? = "2020-01-01",
    addedAt: String? = "2024-06-01T12:00:00Z",
    isEpisode: Bool = false,
    hasFeatures: Bool = true
) -> TrackRow {
    let id = "t\(index)"
    let playable = Playable(
        id: id,
        name: title,
        uri: isEpisode ? "spotify:episode:\(id)" : "spotify:track:\(id)",
        durationMS: durationMS,
        popularity: popularity,
        artists: artist.map { [TrackArtist(name: $0)] },
        album: TrackAlbum(id: "a\(index)"),
        type: isEpisode ? .episode : .track
    )
    return TrackRow(
        originalIndex: index,
        playable: playable,
        addedAt: addedAt,
        features: hasFeatures
            ? AudioFeatures(
                id: id, tempo: tempo, energy: energy, danceability: danceability,
                loudness: loudness, valence: valence, acousticness: acousticness,
                durationMS: durationMS
            )
            : nil,
        albumReleaseDate: releaseDate
    )
}

// MARK: - Attribute values

@Suite("Attribute values")
struct AttributeValueTests {

    @Test("0–1 features are presented as 0–100")
    func normalizedFeaturesScale() {
        let row = makeRow(index: 0, energy: 0.734, danceability: 0.5, valence: 0.129, acousticness: 0.999)
        #expect(row.numericValue(for: .energy) == 73)
        #expect(row.numericValue(for: .dance) == 50)
        #expect(row.numericValue(for: .valence) == 13)
        #expect(row.numericValue(for: .acoustic) == 100)
    }

    @Test("Tempo and loudness round to whole units, keeping loudness negative")
    func tempoAndLoudness() {
        let row = makeRow(index: 0, tempo: 128.62, loudness: -7.41)
        #expect(row.numericValue(for: .bpm) == 129)
        #expect(row.numericValue(for: .loud) == -7)
        #expect(row.displayValue(for: .loud) == "-7")
    }

    @Test("Position displays 1-based even though it sorts 0-based")
    func orderIsOneBasedInDisplay() {
        let row = makeRow(index: 0)
        #expect(row.numericValue(for: .order) == 0)
        #expect(row.displayValue(for: .order) == "1")
    }

    @Test("Duration renders as m:ss with a padded seconds field")
    func durationFormatting() {
        #expect(TrackRow.formatDuration(ms: 200_000) == "3:20")
        #expect(TrackRow.formatDuration(ms: 65_000) == "1:05")
        #expect(TrackRow.formatDuration(ms: 0) == "0:00")
        #expect(TrackRow.formatDuration(ms: 3_600_000) == "60:00")
    }

    @Test("Length falls back to the track's own duration when features are missing")
    func lengthFallsBackToTrackDuration() {
        let row = makeRow(index: 0, durationMS: 185_000, hasFeatures: false)
        #expect(row.numericValue(for: .length) == 185_000)
        #expect(row.displayValue(for: .length) == "3:05")
    }

    @Test("A missing feature yields nil, not zero - zero would sort as a real value")
    func missingFeaturesAreNil() {
        let row = makeRow(index: 0, hasFeatures: false)
        for attribute in Attribute.allCases where attribute.isAudioFeature {
            #expect(row.numericValue(for: attribute) == nil, "\(attribute) should be nil")
            #expect(row.displayValue(for: attribute).isEmpty, "\(attribute) should render empty")
        }
    }

    @Test("Spotify's epoch placeholder added-date is treated as unknown")
    func epochAddedDateIsUnknown() {
        #expect(validAddedAt("1970-01-01T00:00:00Z") == nil)
        #expect(validAddedAt("") == nil)
        #expect(validAddedAt(nil) == nil)
        #expect(validAddedAt("2024-06-01T12:00:00Z") == "2024-06-01T12:00:00Z")

        let row = makeRow(index: 0, addedAt: "1970-01-01T00:00:00Z")
        #expect(row.textValue(for: .added) == nil)
    }

    @Test("Added date is trimmed to the day")
    func addedDateTrimmed() {
        let row = makeRow(index: 0, addedAt: "2024-06-01T12:34:56Z")
        #expect(row.textValue(for: .added) == "2024-06-01")
    }

    @Test("Only real Spotify URIs are savable - local files are dropped")
    func savableURIs() {
        #expect(makeRow(index: 0).savableURI == "spotify:track:t0")
        #expect(makeRow(index: 1, isEpisode: true).savableURI == "spotify:episode:t1")

        let local = TrackRow(
            originalIndex: 2,
            playable: Playable(id: nil, name: "Local", uri: "spotify:local:x:y:z", type: .track)
        )
        #expect(local.savableURI == nil)
    }
}

// MARK: - Arranging

@Suite("Arranging")
struct ArrangingTests {

    @Test("Ascending and descending are mirror images")
    func directionReverses() {
        let rows = [
            makeRow(index: 0, tempo: 120),
            makeRow(index: 1, tempo: 90),
            makeRow(index: 2, tempo: 150),
        ]
        let ascending = PlaylistSorter.ordered(rows, by: .attribute(.bpm, .ascending))
        let descending = PlaylistSorter.ordered(rows, by: .attribute(.bpm, .descending))

        #expect(ascending.map(\.originalIndex) == [1, 0, 2])
        #expect(descending.map(\.originalIndex) == [2, 0, 1])
    }

    @Test("Rows with no value sort last in BOTH directions")
    func nilsAlwaysSinkRegardlessOfDirection() {
        let rows = [
            makeRow(index: 0, tempo: 120),
            makeRow(index: 1, hasFeatures: false),
            makeRow(index: 2, tempo: 90),
        ]

        let ascending = PlaylistSorter.ordered(rows, by: .attribute(.bpm, .ascending))
        #expect(ascending.map(\.originalIndex) == [2, 0, 1])

        let descending = PlaylistSorter.ordered(rows, by: .attribute(.bpm, .descending))
        #expect(descending.last?.originalIndex == 1, "the featureless row must stay at the bottom")
    }

    @Test("Ties fall back to original order, so arranging is stable and repeatable")
    func tiesAreStable() {
        let rows = (0..<6).map { makeRow(index: $0, tempo: 120) }
        let ordered = PlaylistSorter.ordered(rows, by: .attribute(.bpm, .ascending))
        #expect(ordered.map(\.originalIndex) == [0, 1, 2, 3, 4, 5])

        let rearranged = PlaylistSorter.ordered(ordered.shuffled(), by: .attribute(.bpm, .ascending))
        #expect(rearranged.map(\.originalIndex) == [0, 1, 2, 3, 4, 5])
    }

    @Test("Text attributes sort with a natural, case-insensitive comparison")
    func textSorting() {
        let rows = [
            makeRow(index: 0, title: "banana"),
            makeRow(index: 1, title: "Apple"),
            makeRow(index: 2, title: "cherry"),
        ]
        let ordered = PlaylistSorter.ordered(rows, by: .attribute(.title, .ascending))
        #expect(ordered.map(\.playable.name) == ["Apple", "banana", "cherry"])
    }

    @Test("ISO release dates sort chronologically as text")
    func releaseDatesSortChronologically() {
        let rows = [
            makeRow(index: 0, releaseDate: "2020-03-01"),
            makeRow(index: 1, releaseDate: "1999-12-31"),
            makeRow(index: 2, releaseDate: "2020-01-15"),
        ]
        let ordered = PlaylistSorter.ordered(rows, by: .attribute(.release, .ascending))
        #expect(ordered.map(\.albumReleaseDate) == ["1999-12-31", "2020-01-15", "2020-03-01"])
    }

    @Test("Original order is the playlist as Spotify returned it")
    func originalOrderRestoresThePlaylist() {
        var rows = (0..<8).map { makeRow(index: $0, tempo: Double(200 - $0 * 7)) }
        ArtistSeparation.assignIndices(to: &rows)
        let scrambled = PlaylistSorter.ordered(rows, by: .attribute(.bpm, .ascending))

        #expect(PlaylistSorter.ordered(scrambled, by: .originalOrder).map(\.originalIndex) == Array(0..<8))
        #expect(
            PlaylistSorter.ordered(rows, by: .originalOrder.reversed).map(\.originalIndex)
                == Array((0..<8).reversed()),
            "reversing original order flips the playlist, which is what a second # tap does"
        )
    }

    @Test("Every Arrangement orders a mixed playlist without dropping a track", arguments: Arrangement.all)
    func everyArrangementOrders(arrangement: Arrangement) {
        var rows = (0..<12).map {
            makeRow(index: $0, title: "T\($0)", tempo: Double(90 + $0 * 3), hasFeatures: $0 % 3 != 0)
        }
        rows.append(makeRow(index: 12, artist: nil, isEpisode: true, hasFeatures: false))
        ArtistSeparation.assignIndices(to: &rows)

        let ordered = PlaylistSorter.ordered(rows, by: arrangement)
        #expect(ordered.count == rows.count)
        #expect(Set(ordered.map(\.id)) == Set(rows.map(\.id)))
    }

    @Test("A different seed is a different shuffle")
    func seedsProduceDifferentShuffles() {
        let rows = (0..<40).map { makeRow(index: $0) }
        let before = PlaylistSorter.ordered(rows, by: .shuffle(seed: 1)).map(\.id)
        let after = PlaylistSorter.ordered(rows, by: .shuffle(seed: 2)).map(\.id)
        #expect(before != after, "40 tracks reproducing the exact order is vanishingly unlikely")
        #expect(Set(before) == Set(after), "a shuffle keeps every track")
    }

    /// The seed has to determine the order completely, and identically on every
    /// launch - otherwise a shuffled screenshot could never be reproduced, and
    /// `canSave` could not tell one shuffle from another.
    @Test("The same seed is the same shuffle, every time and in every process")
    func shufflesAreReproducible() {
        let rows = (0..<40).map { makeRow(index: $0) }
        let first = PlaylistSorter.ordered(rows, by: .shuffle(seed: 99)).map(\.id)
        let second = PlaylistSorter.ordered(rows.shuffled(), by: .shuffle(seed: 99)).map(\.id)
        #expect(first == second)

        // Pinned against a literal: this is what catches anyone swapping the
        // mixer for `Hasher`, which is seeded per process.
        #expect(Array(first.prefix(6)) == [11, 23, 30, 34, 15, 35])
    }

    @Test("Shuffle ignores direction - it has none to ignore")
    func shuffleHasNoDirection() {
        #expect(Arrangement.shuffle(seed: 7).direction == nil)
        #expect(Arrangement.shuffle(seed: 7).reversed == .shuffle(seed: 7))
    }
}

// MARK: - BPM filter

@Suite("BPM filter")
struct BPMFilterTests {

    @Test("An inactive filter passes everything")
    func inactiveFilterPassesAll() {
        let filter = BPMFilter()
        #expect(!filter.isActive)
        #expect(filter.accepts(makeRow(index: 0, tempo: 12)))
        #expect(filter.accepts(makeRow(index: 1, tempo: 400)))
    }

    @Test("Bounds are inclusive")
    func boundsAreInclusive() {
        let filter = BPMFilter(minBPM: 100, maxBPM: 140, includeDoubled: false)
        #expect(filter.accepts(makeRow(index: 0, tempo: 100)))
        #expect(filter.accepts(makeRow(index: 1, tempo: 140)))
        #expect(!filter.accepts(makeRow(index: 2, tempo: 99)))
        #expect(!filter.accepts(makeRow(index: 3, tempo: 141)))
    }

    @Test("A one-sided range is open at the other end")
    func openEndedRanges() {
        let minOnly = BPMFilter(minBPM: 120, maxBPM: nil, includeDoubled: false)
        #expect(minOnly.accepts(makeRow(index: 0, tempo: 900)))
        #expect(!minOnly.accepts(makeRow(index: 1, tempo: 119)))

        let maxOnly = BPMFilter(minBPM: nil, maxBPM: 120, includeDoubled: false)
        #expect(maxOnly.accepts(makeRow(index: 2, tempo: 10)))
        #expect(!maxOnly.accepts(makeRow(index: 3, tempo: 121)))
    }

    @Test("Doubled BPM admits half-time detections when enabled, and not when disabled")
    func doubledBPM() {
        let row = makeRow(index: 0, tempo: 70)

        let withDoubling = BPMFilter(minBPM: 130, maxBPM: 150, includeDoubled: true)
        #expect(withDoubling.accepts(row), "70 doubles to 140, inside 130–150")

        let withoutDoubling = BPMFilter(minBPM: 130, maxBPM: 150, includeDoubled: false)
        #expect(!withoutDoubling.accepts(row))
    }

    @Test("Rows with no BPM are never hidden - filtering must not silently drop episodes")
    func rowsWithoutBPMAlwaysPass() {
        let filter = BPMFilter(minBPM: 100, maxBPM: 140)
        #expect(filter.accepts(makeRow(index: 0, hasFeatures: false)))
        #expect(filter.accepts(makeRow(index: 1, isEpisode: true, hasFeatures: false)))
    }

    /// Was `arrangeOrdersThenFilters`, against a `PlaylistSorter.arrange` that
    /// no longer exists - ADR-0002 wanted no filter-aware payload builder in
    /// the shared layer. The behaviour it covered is the same, asserted where
    /// it now lives.
    @Test("Filtering happens after arranging, and preserves the arranged order")
    func arrangeOrdersThenFilters() {
        let rows = [
            makeRow(index: 0, tempo: 150),
            makeRow(index: 1, tempo: 100),
            makeRow(index: 2, tempo: 200),
            makeRow(index: 3, tempo: 125),
        ]
        let filter = BPMFilter(minBPM: 110, maxBPM: 160, includeDoubled: false)
        let arranged = PlaylistSorter.ordered(rows, by: .attribute(.bpm, .ascending))
            .filter { filter.accepts($0) }
        #expect(arranged.map { Int($0.numericValue(for: .bpm)!) } == [125, 150])
    }
}

// MARK: - Artist separation

@Suite("Artist separation")
struct ArtistSeparationTests {

    @Test("Every row gets a unique consecutive index")
    func indicesArePermutation() {
        var rows = (0..<20).map { makeRow(index: $0, artist: "Artist \($0 % 4)") }
        ArtistSeparation.assignIndices(to: &rows)

        let indices = rows.compactMap(\.artistSeparationIndex).sorted()
        #expect(indices == Array(0..<20))
    }

    @Test("A dominant artist stops being back-to-back")
    func dominantArtistIsSpread() {
        // Six tracks by one artist followed by six others - the worst case.
        var rows: [TrackRow] = []
        for index in 0..<6 { rows.append(makeRow(index: index, artist: "Heavy")) }
        for index in 6..<12 { rows.append(makeRow(index: index, artist: "Other \(index)")) }

        ArtistSeparation.assignIndices(to: &rows)
        let ordered = PlaylistSorter.ordered(rows, by: .artistSeparation)
        let artists = ordered.map { $0.playable.primaryArtistName ?? "" }

        var longestRun = 1
        var currentRun = 1
        for pair in zip(artists, artists.dropFirst()) {
            currentRun = pair.0 == pair.1 ? currentRun + 1 : 1
            longestRun = max(longestRun, currentRun)
        }
        #expect(longestRun <= 2, "got \(artists)")
    }

    @Test("Artist-less entries are placed instead of crashing")
    func episodesDoNotCrash() {
        var rows = [
            makeRow(index: 0, artist: "A"),
            makeRow(index: 1, artist: nil, isEpisode: true, hasFeatures: false),
            makeRow(index: 2, artist: "A"),
            makeRow(index: 3, artist: nil, isEpisode: true, hasFeatures: false),
        ]
        ArtistSeparation.assignIndices(to: &rows)
        #expect(rows.compactMap(\.artistSeparationIndex).sorted() == [0, 1, 2, 3])
    }

    @Test("A single track and an empty playlist are both handled")
    func degenerateInputs() {
        var empty: [TrackRow] = []
        ArtistSeparation.assignIndices(to: &empty)
        #expect(empty.isEmpty)

        var single = [makeRow(index: 0)]
        ArtistSeparation.assignIndices(to: &single)
        #expect(single[0].artistSeparationIndex == 0)
    }
}

// MARK: - Save naming

@Suite("Save naming")
struct SaveNamingTests {

    /// Naming used to read the *column header*, so a saved playlist came back
    /// abbreviated: "ordered by increasing Dance", "…increasing Pop.". Those
    /// abbreviations exist to fit a 60pt column and die with the table, so
    /// naming now reads the Attribute's own name. This is a deliberate change
    /// to what gets written to a real Spotify account; it is pinned here so it
    /// stays a decision rather than a side effect.
    @Test("Saved names spell the Attribute out rather than abbreviating it")
    func namesAreNotColumnHeaders() {
        let expected: [(Attribute, String)] = [
            (.dance, "increasing Danceability"),
            (.loud, "increasing Loudness"),
            (.pop, "increasing Popularity"),
            (.acoustic, "increasing Acousticness"),
            (.release, "increasing Release date"),
            (.added, "increasing Date added"),
            (.order, "increasing Original order"),
        ]
        for (attribute, name) in expected {
            #expect(Arrangement.attribute(attribute, .ascending).name == name)
        }
    }

    @Test("New playlists are named after the Arrangement")
    func playlistName() {
        #expect(
            SaveNaming.playlistName(original: "Long Run", arrangement: .attribute(.bpm, .ascending))
                == "Long Run ordered by increasing BPM"
        )
    }

    @Test("A directionless Arrangement names the playlist without a direction")
    func directionlessPlaylistName() {
        #expect(
            SaveNaming.playlistName(original: "Long Run", arrangement: .artistSeparation)
                == "Long Run ordered by Artist separation"
        )
        #expect(
            SaveNaming.playlistName(original: "Long Run", arrangement: .shuffled)
                == "Long Run ordered by Shuffle"
        )
    }

    @Test("An existing description is preserved ahead of the Sortify note")
    func descriptionKeepsOriginal() {
        let description = SaveNaming.playlistDescription(
            original: "Steady tempo", arrangement: .attribute(.bpm, .descending)
        )
        #expect(description == "Steady tempo - Sorted by decreasing BPM with Sortify")
    }

    @Test("Blank, whitespace and the literal string \"null\" are all treated as no description")
    func descriptionHandlesEmptyValues() {
        for original in [nil, "", "   ", "null"] as [String?] {
            let description = SaveNaming.playlistDescription(
                original: original, arrangement: .attribute(.valence, .ascending)
            )
            #expect(description == "Sorted by increasing Valence with Sortify", "failed for \(String(describing: original))")
        }
    }
}
