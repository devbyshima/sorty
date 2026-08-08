import Foundation
import Testing

/// Tracks an Arrangement can't place used to sink to the bottom showing a dash,
/// with an explanation that only appeared when *every* track failed - so in the
/// common case, where some did, a run of blank rows read as a bug in the app.
@Suite("Unrankable tracks")
struct UnrankableTests {

    private func track(_ index: Int, tempo: Double? = 120, artist: String? = "Artist") -> TrackRow {
        TrackRow(
            originalIndex: index,
            playable: Playable(
                id: "t\(index)", name: "Track \(index)", uri: "spotify:track:t\(index)",
                durationMS: 200_000, popularity: 50,
                artists: artist.map { [TrackArtist(name: $0)] },
                album: TrackAlbum(id: "a"), type: .track
            ),
            features: tempo.map { AudioFeatures(id: "t\(index)", tempo: $0) },
            albumReleaseDate: "2020-01-01"
        )
    }

    private func episode(_ index: Int) -> TrackRow {
        TrackRow(
            originalIndex: index,
            playable: Playable(
                id: "e\(index)", name: "Episode \(index)", uri: "spotify:episode:e\(index)",
                durationMS: 1_800_000, popularity: nil, artists: nil, album: nil, type: .episode
            )
        )
    }

    // MARK: - The four cases

    @Test("Nothing missing: everything is ranked and there is no group")
    func noneMissing() {
        let rows = (0..<4).map { track($0, tempo: Double(100 + $0)) }
        let result = PlaylistSorter.partition(rows, by: .attribute(.bpm, .ascending))

        #expect(result.ranked.count == 4)
        #expect(result.unrankable.isEmpty, "no group header may appear when nothing is unrankable")
    }

    @Test("Some missing: the rest still rank, and the missing ones group up")
    func someMissing() {
        let rows = [track(0, tempo: 140), track(1, tempo: nil), track(2, tempo: 90), track(3, tempo: nil)]
        let result = PlaylistSorter.partition(rows, by: .attribute(.bpm, .ascending))

        #expect(result.ranked.map(\.originalIndex) == [2, 0], "ranked, in arrangement order")
        #expect(result.unrankable.map(\.originalIndex) == [1, 3])
    }

    @Test("All missing: nothing is ranked and every track is in the group")
    func allMissing() {
        let rows = (0..<3).map { track($0, tempo: nil) }
        let result = PlaylistSorter.partition(rows, by: .attribute(.bpm, .ascending))

        #expect(result.ranked.isEmpty)
        #expect(result.unrankable.count == 3)
    }

    @Test("Podcast episodes are unrankable by anything measured from music")
    func episodesAreUnrankable() {
        let rows = [track(0, tempo: 120), episode(1), track(2, tempo: 90)]
        let result = PlaylistSorter.partition(rows, by: .attribute(.bpm, .ascending))

        #expect(result.ranked.map(\.originalIndex) == [2, 0])
        #expect(result.unrankable.map(\.originalIndex) == [1])
    }

    // MARK: - What counts as unrankable

    @Test("An Arrangement that computes its own order can rank everything")
    func computedArrangementsRankEverything() {
        let rows = [track(0, tempo: nil), episode(1), track(2)]
        for arrangement in [Arrangement.artistSeparation, .shuffled, .originalOrder] {
            let result = PlaylistSorter.partition(rows, by: arrangement)
            #expect(result.unrankable.isEmpty, "\(arrangement.name) should place every track")
            #expect(result.ranked.count == 3)
        }
    }

    @Test("An episode has no artist, so arranging by artist groups it")
    func episodesHaveNoArtist() {
        let rows = [track(0), episode(1)]
        let result = PlaylistSorter.partition(rows, by: .attribute(.artist, .ascending))

        #expect(result.unrankable.map(\.originalIndex) == [1])
    }

    @Test("Order and title are on every track, so nothing is ever unrankable by them")
    func alwaysPresentAttributes() {
        let rows = [track(0, tempo: nil), episode(1)]
        for attribute in [Attribute.order, .title] {
            let result = PlaylistSorter.partition(rows, by: .attribute(attribute, .ascending))
            #expect(result.unrankable.isEmpty, "\(attribute)")
        }
    }

    // MARK: - Why they are there

    @Test("The reason separates a podcast episode from a track nobody measured")
    func reasonsAreDistinguished() {
        #expect(UnrankableReason(for: episode(0), attribute: .bpm) == .episode)
        #expect(UnrankableReason(for: track(1, tempo: nil), attribute: .bpm) == .notMeasured)
    }

    @Test("A value Spotify simply didn't supply is neither of those")
    func absentMetadataIsItsOwnReason() {
        let noReleaseDate = TrackRow(
            originalIndex: 0,
            playable: Playable(id: "t", name: "T", uri: "spotify:track:t", type: .track)
        )
        #expect(UnrankableReason(for: noReleaseDate, attribute: .release) == .missing)
    }

    // MARK: - Groups

    @Test("A group's stated count matches what is actually in it")
    func countMatchesContents() {
        let rows = [track(0, tempo: 120), episode(1), track(2, tempo: nil), episode(3)]
        let groups = UnrankableGroup.groups(
            for: PlaylistSorter.partition(rows, by: .attribute(.bpm, .ascending)).unrankable,
            attribute: .bpm,
            providerNote: nil
        )

        for group in groups {
            #expect(group.title.contains("\(group.rows.count)"))
            #expect(group.rows.count == group.count)
        }
        #expect(groups.map(\.count).reduce(0, +) == 3)
    }

    @Test("Episodes and unmeasured tracks are grouped apart, episodes last")
    func groupsAreSeparatedByReason() {
        let rows = [episode(0), track(1, tempo: nil)]
        let groups = UnrankableGroup.groups(
            for: PlaylistSorter.partition(rows, by: .attribute(.bpm, .ascending)).unrankable,
            attribute: .bpm,
            providerNote: nil
        )

        #expect(groups.map(\.reason) == [.notMeasured, .episode])
    }

    @Test("A group names the Attribute it couldn't rank by")
    func groupsNameTheAttribute() {
        let groups = UnrankableGroup.groups(
            for: [track(0, tempo: nil)], attribute: .bpm, providerNote: nil
        )
        #expect(groups.first?.detail.contains("BPM") == true)
    }

    /// The provider's own explanation used to appear only when *every* track
    /// failed. It belongs here, where it fires whenever anything did.
    @Test("The provider's explanation is carried into the group that needs it")
    func providerNoteReachesTheGroup() {
        let note = "ReccoBeats had no acoustic data for 5 of 68 tracks."
        let groups = UnrankableGroup.groups(
            for: [track(0, tempo: nil), episode(1)], attribute: .bpm, providerNote: note
        )

        let unmeasured = groups.first { $0.reason == .notMeasured }
        #expect(unmeasured?.detail.hasPrefix(note) == true)

        let episodes = groups.first { $0.reason == .episode }
        #expect(episodes?.detail.contains("ReccoBeats") == false, "an episode is not a provider miss")
    }

    @Test("Nothing unrankable means no groups at all")
    func noGroupsWhenNothingIsUnrankable() {
        #expect(UnrankableGroup.groups(for: [], attribute: .bpm, providerNote: nil).isEmpty)
    }

    /// "BPM is measured from music" is true. "Release date is measured from
    /// music" is not - a Spotify episode has a release date, Sortify just
    /// doesn't read one, and story 27 is about saying the *right* why.
    @Test("The episode reason says why for that Attribute, not a general one")
    func episodeCopyMatchesTheAttribute() {
        let episodes = [episode(0)]

        let byTempo = UnrankableGroup.groups(for: episodes, attribute: .bpm, providerNote: nil)
        #expect(byTempo.first?.detail.contains("measured from music") == true)

        let byDate = UnrankableGroup.groups(for: episodes, attribute: .release, providerNote: nil)
        #expect(byDate.first?.detail.contains("Sortify doesn't read Release date") == true)
        #expect(byDate.first?.detail.contains("isn't music") == false)
    }

    @Test("Every group says the tracks are kept")
    func everyGroupSaysTheTracksAreKept() {
        let rows = [episode(0), track(1, tempo: nil)]
        for group in UnrankableGroup.groups(for: rows, attribute: .bpm, providerNote: nil) {
            #expect(group.detail.contains("saved with it"), "\(group.reason)")
        }
    }

    @Test("A track with no place in the arrangement is spoken without a position")
    func unrankableRowsAreSpokenWithoutAPosition() {
        let text = TrackRowText(row: track(0, tempo: nil), position: nil, arrangement: .attribute(.bpm, .ascending))
        #expect(text.position == nil)
        #expect(text.spoken == "Track 0 by Artist. BPM unavailable.")
    }
}
