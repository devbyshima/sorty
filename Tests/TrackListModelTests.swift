import Foundation
import Testing

@Suite("Track list model")
@MainActor
struct TrackListModelTests {

    private func loadedModel(
        count: Int = 8,
        ownerID: String = "me",
        service: RecordingMusicService? = nil,
        provider: (any AudioFeatureProviding)? = nil
    ) async -> (TrackListModel, RecordingMusicService) {
        let items = sampleItems(count: count)
        let resolvedService = service ?? RecordingMusicService(items: items)
        let model = TrackListModel(
            playlist: samplePlaylist(ownerID: ownerID),
            service: resolvedService,
            featureProvider: provider ?? StubFeatureProvider(table: sampleFeatures(count: count)),
            currentUserID: "me"
        )
        await model.load()
        return (model, resolvedService)
    }

    @Test("Loading populates rows, features, album dates and artist separation")
    func loadEnriches() async {
        let (model, _) = await loadedModel()

        #expect(model.phase == .ready)
        #expect(model.rows.count == 8)
        #expect(model.rows.allSatisfy { $0.features != nil })
        #expect(model.rows.allSatisfy { $0.albumReleaseDate != nil })
        #expect(model.rows.allSatisfy { $0.artistSeparationIndex != nil })
        #expect(model.oldestAddedAt == "2024-01-01T00:00:00Z")
    }

    @Test("An empty playlist reports the empty phase rather than ready")
    func emptyPlaylist() async {
        let model = TrackListModel(
            playlist: samplePlaylist(),
            service: RecordingMusicService(items: []),
            featureProvider: StubFeatureProvider(),
            currentUserID: "me"
        )
        await model.load()
        #expect(model.phase == .empty)
    }

    @Test("A freshly loaded playlist starts in its original order")
    func launchesInOriginalOrder() async {
        let (model, _) = await loadedModel()
        #expect(model.arrangement == .originalOrder)
        #expect(model.arrangedRows.map(\.originalIndex) == Array(0..<8))
    }

    @Test("Save stays disabled until the arrangement actually changes")
    func saveGating() async {
        let (model, _) = await loadedModel()
        #expect(!model.canSave, "a freshly loaded playlist matches what's on Spotify")

        model.apply(.attribute(.bpm, .ascending))
        #expect(model.canSave)
    }

    @Test("Returning to the original arrangement disables save again")
    func saveGatingRoundTrip() async {
        let (model, _) = await loadedModel()
        model.apply(.attribute(.bpm, .ascending))
        #expect(model.canSave)

        model.apply(.originalOrder)
        #expect(!model.canSave, "back to the arrangement that's on Spotify, so there's nothing to save")
    }

    /// Drives the model the way the screen does - through the chip row - so the
    /// composition in `ArrangementChip` and its effect on the playlist are
    /// asserted together rather than separately.
    private func tap(_ basis: Arrangement.Basis, on model: TrackListModel) {
        guard let chip = ArrangementChip.row(for: model.arrangement).first(where: { $0.basis == basis })
        else {
            Issue.record("no chip for \(basis.name)")
            return
        }
        model.apply(chip.tapped)
    }

    @Test("Tapping the active chip reverses it; a different one starts ascending")
    func chipSelection() async {
        let (model, _) = await loadedModel()

        tap(.attribute(.bpm), on: model)
        #expect(model.arrangement == .attribute(.bpm, .ascending))

        tap(.attribute(.bpm), on: model)
        #expect(model.arrangement == .attribute(.bpm, .descending))

        tap(.attribute(.energy), on: model)
        #expect(model.arrangement == .attribute(.energy, .ascending), "switching resets direction")
    }

    @Test("The Original order chip reverses the playlist on a second tap")
    func originalOrderChipReverses() async {
        let (model, _) = await loadedModel()

        tap(.attribute(.bpm), on: model)
        tap(.originalOrder, on: model)
        #expect(model.arrangement == .originalOrder)
        #expect(model.arrangedRows.map(\.originalIndex) == Array(0..<8))

        tap(.originalOrder, on: model)
        #expect(model.arrangement == .attribute(.order, .descending))
        #expect(model.arrangedRows.map(\.originalIndex) == Array((0..<8).reversed()))
    }

    @Test("Tapping Artist separation or Shuffle twice never means two things")
    func directionlessChipsDoNotToggle() async {
        let (model, _) = await loadedModel(count: 40)

        for basis in [Arrangement.Basis.artistSeparation, .shuffle] {
            tap(basis, on: model)
            let arrangement = model.arrangement
            let order = model.arrangedRows.map(\.id)

            tap(basis, on: model)
            #expect(model.arrangement == arrangement, "\(basis.name) has no direction to flip")
            #expect(model.arrangement.direction == nil)
            #expect(model.arrangedRows.map(\.id) == order, "\(basis.name) must not re-order on a second tap")
        }
    }

    @Test("Re-rolling is what reshuffles, and it is a control of its own")
    func rerollReshuffles() async {
        let (model, _) = await loadedModel(count: 40)

        model.reroll()
        #expect(model.arrangement.basis == .shuffle)
        let first = model.arrangedRows.map(\.id)

        model.reroll()
        #expect(model.arrangedRows.map(\.id) != first)
    }

    @Test("Re-rolling from another Arrangement applies Shuffle")
    func rerollAppliesShuffle() async {
        let (model, _) = await loadedModel()
        model.apply(.attribute(.bpm, .descending))

        model.reroll()
        #expect(model.arrangement.basis == .shuffle)
    }

    /// The bug the seed exists to fix: before it, one Arrangement value stood
    /// for whichever random order was loaded, so after saving a shuffle the
    /// listener could re-roll, watch the list change, and find Save still
    /// greyed out.
    @Test("Re-rolling after a save re-arms Save")
    func rerollAfterSavingReArmsSave() async {
        let (model, _) = await loadedModel(count: 40)

        model.reroll()
        await model.saveAsNewPlaylist()
        #expect(!model.canSave, "what's on Spotify now matches what's on screen")

        let before = model.arrangedRows.map(\.id)
        model.reroll()
        #expect(model.arrangedRows.map(\.id) != before, "the order changed")
        #expect(model.canSave, "so Save has to notice")
    }

    @Test("Saving a new playlist names it after the Arrangement and writes the visible order")
    func saveNewPlaylist() async {
        let (model, service) = await loadedModel()
        model.apply(.attribute(.bpm, .ascending))
        await model.saveAsNewPlaylist()

        let created = await service.createdPlaylists
        #expect(created.count == 1)
        #expect(created.first?.name == "Test Playlist ordered by increasing BPM")
        #expect(created.first?.description == "Original - Sorted by increasing BPM with Sorty")

        let writes = await service.writes
        #expect(writes.count == 1)
        #expect(writes.first?.playlistID == "new-playlist")
        #expect(writes.first?.uris == model.arrangedRows.compactMap(\.savableURI))
    }

    @Test("Overwriting targets the original playlist and creates nothing")
    func overwrite() async {
        let (model, service) = await loadedModel()
        #expect(model.mayOverwriteThisPlaylist)

        model.apply(.attribute(.energy, .ascending))
        await model.overwrite()

        #expect(await service.createdPlaylists.isEmpty)
        #expect(await service.writes.first?.playlistID == "p1")
    }

    @Test("Overwrite is not offered for a playlist owned by someone else")
    func overwriteHiddenForOthers() async {
        let (model, _) = await loadedModel(ownerID: "someone-else")
        #expect(!model.mayOverwriteThisPlaylist)
        #expect(!model.saveActions.contains { $0.kind == .overwrite })
        #expect(
            model.saveActions.contains { $0.kind == .newPlaylist },
            "a refusal has to come with a way forward"
        )
    }

    @Test("A successful save re-arms the gate only after another change")
    func saveResetsDirtyState() async {
        let (model, _) = await loadedModel()
        model.apply(.attribute(.bpm, .ascending))
        await model.saveAsNewPlaylist()

        #expect(!model.canSave, "what's on Spotify now matches what's on screen")

        model.apply(.attribute(.valence, .ascending))
        #expect(model.canSave)
    }

    @Test("A 403 on write is reported as a permissions problem, not a generic failure")
    func forbiddenWriteExplained() async {
        let items = sampleItems(count: 4)
        let service = RecordingMusicService(items: items, failWrites: true)
        let (model, _) = await loadedModel(count: 4, service: service)

        model.apply(.attribute(.bpm, .ascending))
        await model.overwrite()

        guard case .failed(let message) = model.saveStatus else {
            Issue.record("expected a failure, got \(model.saveStatus)")
            return
        }
        #expect(message.contains("can't be modified"))
    }

    @Test("Saving with everything filtered out refuses rather than clearing the playlist")
    func refusesToSaveEmptySelection() async {
        let (model, service) = await loadedModel()
        model.filter = BPMFilter(minBPM: 5, maxBPM: 6, includeDoubled: false)
        #expect(model.arrangedRows.isEmpty)

        await model.saveAsNewPlaylist()

        guard case .failed(let message) = model.saveStatus else {
            Issue.record("expected a refusal, got \(model.saveStatus)")
            return
        }
        #expect(message.contains("Nothing to save"))
        #expect(await service.writes.isEmpty, "an empty PUT would wipe the playlist")
    }

    @Test("The BPM filter narrows the visible rows and reports how many are hidden")
    func filteringCountsHiddenRows() async {
        let (model, _) = await loadedModel()
        #expect(model.hiddenRowCount == 0)

        model.filter = BPMFilter(minBPM: 160, maxBPM: 200, includeDoubled: false)
        #expect(model.arrangedRows.count < model.rows.count)
        #expect(model.hiddenRowCount == model.rows.count - model.arrangedRows.count)
    }

    /// The provider's explanation used to be a notice above the list that only
    /// appeared when *every* track failed. It now travels to the group that
    /// actually holds the tracks it explains.
    @Test("When features are missing, the provider's reason reaches the group")
    func providerReasonReachesTheGroup() async {
        let (model, _) = await loadedModel(
            provider: StubFeatureProvider(table: [:], reason: "Nothing found for this playlist.")
        )
        model.apply(.attribute(.bpm, .ascending))

        #expect(model.rows.allSatisfy { $0.features == nil })
        #expect(model.phase == .ready, "the list still works without acoustic data")

        #expect(model.rankedRows.isEmpty)
        let group = model.unrankableGroups.first { $0.reason == .notMeasured }
        #expect(group?.count == 8)
        #expect(group?.detail.hasPrefix("Nothing found for this playlist.") == true)
    }

    @Test("Nothing unrankable means no group headers at all")
    func noGroupsWhenEverythingRanks() async {
        let (model, _) = await loadedModel()
        model.apply(.attribute(.bpm, .ascending))

        #expect(model.rankedRows.count == 8)
        #expect(model.unrankableGroups.isEmpty)
    }

    /// The invariant behind the whole group: using Sorty must never cost a
    /// listener tracks, so a track the provider had nothing for is still
    /// written back - appended at the end, not dropped.
    @Test("Unrankable tracks are saved too, appended after the ranked ones")
    func unrankableTracksAreStillSaved() async {
        var table = sampleFeatures(count: 8)
        table["t3"] = nil
        table["t6"] = nil

        let (model, service) = await loadedModel(provider: StubFeatureProvider(table: table))
        model.apply(.attribute(.bpm, .ascending))

        #expect(model.unrankableGroups.map(\.count).reduce(0, +) == 2)

        await model.saveAsNewPlaylist()
        let written = await service.writes.first?.uris

        #expect(written?.count == 8, "every track is written, including the two it couldn't rank")
        #expect(Set(written ?? []).count == 8)
        #expect(
            Set(written?.suffix(2) ?? []) == ["spotify:track:t3", "spotify:track:t6"],
            "the unrankable ones go at the end"
        )
    }

    /// A listener who can see the order should be able to trust it is the order
    /// that gets written. The groups are shown in a particular sequence, so the
    /// saved list has to follow the same one.
    @Test("What gets written is what the screen shows, in that order")
    func saveOrderMatchesScreenOrder() async {
        var table = sampleFeatures(count: 8)
        table["t2"] = nil
        table["t5"] = nil

        let (model, _) = await loadedModel(provider: StubFeatureProvider(table: table))
        model.apply(.attribute(.bpm, .descending))

        let onScreen = model.rankedRows + model.unrankableGroups.flatMap(\.rows)
        #expect(model.arrangedRows.map(\.id) == onScreen.map(\.id))
        #expect(model.arrangedRows.count == 8)
    }
}

@Suite("Demo catalogue")
struct DemoCatalogTests {

    @Test("The catalogue is deterministic across instantiations")
    func deterministic() {
        let first = DemoCatalog()
        let second = DemoCatalog()
        #expect(first.playlists.map(\.id) == second.playlists.map(\.id))

        let id = first.playlists[0].id
        #expect(first.features(forTrackID: "\(id)-t0")?.tempo == second.features(forTrackID: "\(id)-t0")?.tempo)
    }

    @Test("Every demo playlist has items, and reports a matching count")
    func playlistsArePopulated() {
        let catalog = DemoCatalog()
        #expect(!catalog.playlists.isEmpty)
        for playlist in catalog.playlists {
            let items = catalog.items(forPlaylist: playlist.id)
            #expect(!items.isEmpty, "\(playlist.name) is empty")
            #expect(items.count == playlist.tracks.total)
        }
    }

    @Test("Demo tracks carry features in Spotify's ranges")
    func featureRanges() {
        let catalog = DemoCatalog()
        let playlist = catalog.playlists[0]
        for item in catalog.items(forPlaylist: playlist.id) {
            guard let id = item.track?.id, let features = catalog.features(forTrackID: id) else { continue }
            #expect((60...200).contains(features.tempo ?? 0))
            #expect((0...1).contains(features.energy ?? -1))
            #expect((0...1).contains(features.valence ?? -1))
            #expect((-60 ... 0).contains(features.loudness ?? -100))
        }
    }

    @Test("Every playlist resolves cover artwork, so no card falls back to a glyph")
    func playlistsHaveArtwork() {
        let catalog = DemoCatalog()
        for playlist in catalog.playlists {
            #expect(playlist.cardImageURL != nil, "\(playlist.name) has no cover")
        }
        // Distinct covers, or the library reads as one repeated texture.
        let seeds = catalog.playlists.compactMap { $0.cardImageURL.flatMap(DemoArtwork.Request.init)?.seed }
        #expect(Set(seeds).count == catalog.playlists.count)
    }

    /// Every entry, episodes included. An episode has no album to read artwork
    /// from, so it carries its own - without that, the artwork row in ticket 03
    /// would have a hole in exactly the place this catalogue exists to exercise.
    @Test("Every demo entry resolves cover artwork, tracks and episodes alike")
    func everyEntryHasArtwork() {
        let catalog = DemoCatalog()
        var sawEpisode = false

        for playlist in catalog.playlists {
            for item in catalog.items(forPlaylist: playlist.id) {
                guard let playable = item.track else { continue }
                sawEpisode = sawEpisode || playable.isEpisode
                #expect(playable.coverImageURL != nil, "\(playable.name) has no cover")
            }
        }

        #expect(sawEpisode, "the catalogue should contain episodes to check")
    }

    @Test("Tracks on the same album share one cover, as they would on Spotify")
    func albumArtworkIsSharedWithinAnAlbum() {
        let catalog = DemoCatalog()
        var seedsByAlbum: [String: Set<String>] = [:]

        for item in catalog.items(forPlaylist: "demo-morning") {
            guard let playable = item.track, let album = playable.album, let albumID = album.id,
                  let url = album.images?.first.flatMap({ URL(string: $0.url) }),
                  let seed = DemoArtwork.Request(url: url)?.seed
            else { continue }
            seedsByAlbum[albumID, default: []].insert(seed)
        }

        #expect(seedsByAlbum.count > 1, "the playlist should span several albums")
        for (albumID, seeds) in seedsByAlbum {
            #expect(seeds.count == 1, "\(albumID) resolved \(seeds.count) different covers")
        }
    }

    @Test("Some tracks have no audio features, so the unrankable path has work to do")
    func someTracksLackFeatures() {
        let catalog = DemoCatalog()

        for playlist in catalog.playlists {
            let tracks = catalog.items(forPlaylist: playlist.id)
                .compactMap(\.track)
                .filter { !$0.isEpisode }
            let missing = tracks.filter { $0.id.flatMap { catalog.features(forTrackID: $0) } == nil }

            #expect(!missing.isEmpty, "\(playlist.name) has no featureless tracks")
            #expect(
                missing.count < tracks.count / 4,
                "\(playlist.name) is mostly missing features, which reads as broken rather than patchy"
            )
        }
    }

    @Test("One playlist is long enough that reordering it reads as motion")
    func aPlaylistIsLongEnoughToAnimate() {
        let catalog = DemoCatalog()
        let longest = catalog.playlists.map(\.tracks.total).max() ?? 0
        #expect(longest >= 60, "longest playlist is only \(longest) tracks")
    }

    @Test("The mixed playlist really does contain episodes with no artist")
    func episodesExist() {
        let catalog = DemoCatalog()
        let items = catalog.items(forPlaylist: "demo-mixed")
        let episodes = items.filter { $0.track?.isEpisode == true }
        #expect(episodes.count == 3)
        #expect(episodes.allSatisfy { $0.track?.primaryArtistName == nil })
    }

    @Test("Demo mode refuses writes rather than pretending to save")
    func demoIsReadOnly() async {
        let service = DemoMusicService(pageDelay: .zero)
        #expect(!service.canWriteBack)
        await #expect(throws: DemoModeError.self) {
            try await service.replaceTracks(playlistID: "demo-morning", uris: ["spotify:track:x"])
        }
    }

    @Test("Demo mode streams pages and returns every item")
    func demoStreamsPages() async throws {
        let service = DemoMusicService(pageDelay: .zero)
        let pageCount = Counter()
        let items = try await service.playlistItems(playlistID: "demo-kitchen", ownerID: "demo-user") { _, _ in
            await pageCount.increment()
        }
        #expect(items.count == 31)
        #expect(await pageCount.value > 1, "31 items across 25-item pages should arrive in more than one batch")
    }
}

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}
