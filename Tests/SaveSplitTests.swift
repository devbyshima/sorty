import Foundation
import Testing

/// ADR-0002: the two save paths are separated by what each is allowed to write.
///
/// These assert on what the recording service actually *received*, never on
/// what the model displays. The difference matters: the bug this ticket removes
/// was one where the screen was right and the write was wrong.
@Suite("Save split")
@MainActor
struct SaveSplitTests {

    /// Eight tracks at 100…170 BPM, so a filter can be set that hides most of
    /// them and the count that survives is known exactly.
    private func loadedModel(
        count: Int = 8,
        ownerID: String = "me",
        service: RecordingMusicService? = nil
    ) async -> (TrackListModel, RecordingMusicService) {
        var table: [String: AudioFeatures] = [:]
        for index in 0..<count {
            table["t\(index)"] = AudioFeatures(id: "t\(index)", tempo: Double(100 + index * 10))
        }
        let recorder = service ?? RecordingMusicService(items: sampleItems(count: count))
        let model = TrackListModel(
            playlist: samplePlaylist(ownerID: ownerID, total: count),
            service: recorder,
            featureProvider: StubFeatureProvider(table: table),
            currentUserID: "me"
        )
        await model.load()
        return (model, recorder)
    }

    /// Hides all but the three slowest.
    private var narrowFilter: BPMFilter {
        BPMFilter(minBPM: 100, maxBPM: 120, includeDoubled: false)
    }

    // MARK: - The invariant

    /// **The single most important test in the suite.**
    ///
    /// A 68-track playlist narrowed to 20 by a tempo filter and overwritten used
    /// to be replaced on the listener's real account with those 20 tracks, with
    /// no undo and no dialog. The guarantee is now structural - overwrite is
    /// never handed a list at all - and this is what holds it there.
    @Test("Overwrite writes every track in the playlist even with a filter active")
    func overwriteIgnoresTheFilter() async {
        let (model, service) = await loadedModel()
        model.apply(.attribute(.bpm, .descending))
        model.filter = narrowFilter

        #expect(model.arrangedRows.count == 3, "the filter is hiding five tracks")

        await model.overwrite()

        let written = await service.writes
        #expect(written.count == 1)
        #expect(written.first?.playlistID == "p1")
        #expect(written.first?.uris.count == 8, "every track, not the three on screen")
        #expect(
            Set(written.first?.uris ?? []) == Set((0..<8).map { "spotify:track:t\($0)" }),
            "no track may leave a playlist because a filter was on"
        )
    }

    @Test("Overwrite writes them in Arrangement order, not original order")
    func overwriteIsStillArranged() async {
        let (model, service) = await loadedModel()
        model.apply(.attribute(.bpm, .descending))
        model.filter = narrowFilter

        await model.overwrite()

        let written = await service.writes.first?.uris
        #expect(
            written == (0..<8).reversed().map { "spotify:track:t\($0)" },
            "the whole playlist, but arranged - overwrite reorders, it doesn't restore"
        )
    }

    /// The unfiltered list the invariant is defined against, exposed so it can
    /// be checked directly rather than only through a write.
    @Test("The full order holds every track whatever the filter does")
    func fullOrderIgnoresTheFilter() async {
        let (model, _) = await loadedModel()
        model.apply(.attribute(.bpm, .ascending))
        let unfiltered = model.fullOrder.map(\.id)

        model.filter = narrowFilter
        #expect(model.arrangedRows.count == 3)
        #expect(model.fullOrder.map(\.id) == unfiltered)
        #expect(model.fullOrder.count == model.rows.count)
    }

    // MARK: - The other path

    @Test("Save as new with a filter active writes exactly the filtered subset")
    func newPlaylistWritesTheSubset() async {
        let (model, service) = await loadedModel()
        model.apply(.attribute(.bpm, .ascending))
        model.filter = narrowFilter

        await model.saveAsNewPlaylist()

        let written = await service.writes
        #expect(written.first?.playlistID == "new-playlist")
        #expect(
            written.first?.uris == ["spotify:track:t0", "spotify:track:t1", "spotify:track:t2"],
            "keeping a tempo range is the point of this path"
        )
        #expect(await service.createdPlaylists.count == 1)
    }

    @Test("The subset action states the count it will write, before it writes it")
    func subsetActionStatesItsCount() async {
        let (model, service) = await loadedModel()
        model.apply(.attribute(.bpm, .ascending))
        model.filter = narrowFilter

        let action = model.saveActions.first { $0.kind == .newPlaylist }
        #expect(action?.title == "Save These 3 as a New Playlist")

        await model.saveAsNewPlaylist()
        #expect(
            await service.writes.first?.uris.count == 3,
            "the number on the button is the number that was written"
        )
    }

    /// Unfiltered, a count would only restate the playlist's own length, and it
    /// would change under the listener while tracks were still loading.
    @Test("With no filter the action just says what it does")
    func unfilteredActionCarriesNoCount() async {
        let (model, _) = await loadedModel()
        model.apply(.attribute(.bpm, .ascending))

        #expect(model.saveActions.first { $0.kind == .newPlaylist }?.title == "Save as New Playlist")
    }

    @Test("Saved playlist names derive from the Arrangement, directionless ones included")
    func namesDeriveFromTheArrangement() async {
        for (arrangement, expected) in [
            (Arrangement.attribute(.bpm, .descending), "Test Playlist ordered by decreasing BPM"),
            (.artistSeparation, "Test Playlist ordered by Artist separation"),
            (.shuffled, "Test Playlist ordered by Shuffle"),
        ] {
            let (model, service) = await loadedModel()
            model.apply(arrangement)
            await model.saveAsNewPlaylist()
            #expect(await service.createdPlaylists.first?.name == expected)
        }
    }

    // MARK: - Separate gates

    /// ADR-0002 in the gate rather than only in the payload: narrowing the
    /// filter cannot make the playlist on Spotify stale, because the order it
    /// holds is still the order overwrite would write.
    @Test("A filter change arms the new-playlist path and leaves overwrite alone")
    func filterArmsOnlyTheSubsetPath() async {
        let (model, _) = await loadedModel()
        #expect(!model.canOverwrite, "nothing has changed yet")
        #expect(!model.canSaveAsNewPlaylist)

        model.filter = narrowFilter

        #expect(model.canSaveAsNewPlaylist, "keeping this subset is a real thing to want")
        #expect(!model.canOverwrite, "overwriting would write the order it already has")
        #expect(model.canSave, "the control is still worth reaching for")
    }

    @Test("An Arrangement change arms both")
    func arrangementArmsBoth() async {
        let (model, _) = await loadedModel()
        model.apply(.attribute(.bpm, .descending))

        #expect(model.canOverwrite)
        #expect(model.canSaveAsNewPlaylist)
    }

    @Test("Overwriting disarms overwrite, and a filter alone does not re-arm it")
    func overwriteDisarmsUntilTheArrangementMoves() async {
        let (model, _) = await loadedModel()
        model.apply(.attribute(.bpm, .descending))
        await model.overwrite()

        #expect(!model.canOverwrite, "Spotify holds this order now")

        model.filter = narrowFilter
        #expect(!model.canOverwrite, "the filter never reaches the write, so it can't stale it")

        model.apply(.attribute(.energy, .ascending))
        #expect(model.canOverwrite)
    }

    @Test("Save is unavailable on arrival and available once the Arrangement changes")
    func nothingToSaveOnArrival() async {
        let (model, _) = await loadedModel()
        #expect(!model.canSave)
        #expect(model.saveActions.allSatisfy { !$0.isEnabled })

        model.apply(.attribute(.valence, .descending))
        #expect(model.canSave)
    }

    /// Filtering everything away leaves the subset path nothing to create, but
    /// overwrite is untouched by it - a filter can't empty what it never sees.
    @Test("A filter that hides everything blocks only the path that would obey it")
    func emptySubsetBlocksOnlyTheSubsetPath() async {
        let (model, service) = await loadedModel()
        model.apply(.attribute(.bpm, .ascending))
        model.filter = BPMFilter(minBPM: 5, maxBPM: 6, includeDoubled: false)
        #expect(model.arrangedRows.isEmpty)

        #expect(!model.canSaveAsNewPlaylist)
        #expect(model.canOverwrite)

        await model.saveAsNewPlaylist()
        guard case .failed(let message) = model.saveStatus else {
            Issue.record("expected a refusal, got \(model.saveStatus)")
            return
        }
        #expect(message.contains("Nothing to save"))
        #expect(await service.writes.isEmpty, "an empty PUT would wipe the playlist")
    }

    /// Demo Mode produces Arrangements and saves none of them. Both actions go
    /// dark rather than one - and this is the gate ticket 11's guided connect
    /// flow will hang off, so it is worth pinning before it has a second reader.
    @Test("Demo Mode arms neither path")
    func demoModeArmsNothing() async {
        let model = TrackListModel(
            playlist: DemoCatalog.shared.playlists[0],
            service: DemoMusicService(pageDelay: .zero),
            featureProvider: DemoAudioFeatureProvider(),
            currentUserID: nil
        )
        await model.load()
        model.apply(.attribute(.bpm, .descending))

        #expect(!model.canWriteBack)
        #expect(!model.canSave)
        #expect(!model.canOverwrite)
        #expect(!model.canSaveAsNewPlaylist)
        #expect(model.saveActions.allSatisfy { !$0.isEnabled })
    }

    // MARK: - Reporting

    @Test("Each path says how many tracks went where")
    func resultsSayWhatHappened() async {
        let (overwriter, _) = await loadedModel()
        overwriter.apply(.attribute(.bpm, .descending))
        overwriter.filter = narrowFilter
        await overwriter.overwrite()

        #expect(
            overwriter.saveStatus == .updated("Updated “Test Playlist” with 8 tracks by decreasing BPM."),
            "the count reported is the count written, filter or no filter"
        )

        let (creator, _) = await loadedModel()
        creator.apply(.attribute(.bpm, .descending))
        creator.filter = narrowFilter
        await creator.saveAsNewPlaylist()

        #expect(
            creator.saveStatus
                == .created("Created “Test Playlist ordered by decreasing BPM” with 3 tracks by decreasing BPM.")
        )
    }

    @Test("A playlist that refuses the write explains itself and leaves the new-playlist path open")
    func refusedWriteExplainsAndOffersAWayOn() async {
        let service = RecordingMusicService(items: sampleItems(count: 8), failWrites: true)
        let (model, _) = await loadedModel(service: service)
        model.apply(.attribute(.bpm, .ascending))

        await model.overwrite()

        guard case .failed(let message) = model.saveStatus else {
            Issue.record("expected a failure, got \(model.saveStatus)")
            return
        }
        #expect(message.contains("can't be modified"))
        #expect(message.contains("Save a new playlist instead"), "a refusal needs a way forward")
        #expect(model.saveActions.contains { $0.kind == .newPlaylist && $0.isEnabled })
    }

    /// A failed save must leave the screen able to try again - the gate is
    /// derived from what Spotify actually holds, and a write that threw changed
    /// nothing there.
    @Test("A failed save leaves Save armed to retry")
    func failureLeavesSaveArmed() async {
        let service = RecordingMusicService(items: sampleItems(count: 8), failWrites: true)
        let (model, _) = await loadedModel(service: service)
        model.apply(.attribute(.bpm, .ascending))

        await model.overwrite()

        #expect(model.canOverwrite, "nothing was written, so there is still something to write")
        #expect(model.canSave)
    }
}
