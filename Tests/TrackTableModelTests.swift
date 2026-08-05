import Foundation
import Testing

/// Records what was written back, so save behaviour can be asserted without a
/// network or a Spotify account.
private actor RecordingService: MusicService {
    nonisolated let canWriteBack = true

    private(set) var createdPlaylists: [(name: String, isPublic: Bool, description: String)] = []
    private(set) var writes: [(playlistID: String, uris: [String])] = []

    private let items: [PlaylistItem]
    private let failWrites: Bool

    init(items: [PlaylistItem], failWrites: Bool = false) {
        self.items = items
        self.failWrites = failWrites
    }

    func currentUser() async throws -> SpotifyUser { SpotifyUser(id: "me", displayName: "Me") }

    func playlists(onBatch: @Sendable ([Playlist], Int?) async -> Void) async throws -> [Playlist] { [] }

    func playlistItems(
        playlistID: String,
        ownerID: String,
        onPage: @Sendable ([PlaylistItem], Int) async -> Void
    ) async throws -> [PlaylistItem] {
        await onPage(items, items.count)
        return items
    }

    func albums(ids: [String]) async throws -> [TrackAlbum] {
        ids.map { TrackAlbum(id: $0, name: "Album \($0)", releaseDate: "2019-05-0\(($0.count % 9) + 1)") }
    }

    func createPlaylist(userID: String, name: String, isPublic: Bool, description: String) async throws -> Playlist {
        createdPlaylists.append((name, isPublic, description))
        return Playlist(
            id: "new-playlist", name: name, uri: "spotify:playlist:new",
            owner: PlaylistOwner(id: userID), tracks: PlaylistTrackCount(total: 0)
        )
    }

    func replaceTracks(playlistID: String, uris: [String]) async throws {
        if failWrites { throw SpotifyAPIError.http(status: 403, message: "Forbidden") }
        writes.append((playlistID, uris))
    }
}

private struct StubFeatureProvider: AudioFeatureProviding {
    let displayName = "Stub"
    let table: [String: AudioFeatures]
    let reason: String?

    init(table: [String: AudioFeatures] = [:], reason: String? = nil) {
        self.table = table
        self.reason = reason
    }

    var unavailabilityReason: String? { get async { reason } }

    func features(forTrackIDs trackIDs: [String]) async throws -> [String: AudioFeatures] {
        table.filter { trackIDs.contains($0.key) }
    }
}

private func sampleItems(count: Int, tempoStart: Double = 100) -> [PlaylistItem] {
    (0..<count).map { index in
        PlaylistItem(
            addedAt: "2024-0\((index % 9) + 1)-01T00:00:00Z",
            isLocal: false,
            track: Playable(
                id: "t\(index)",
                name: "Track \(index)",
                uri: "spotify:track:t\(index)",
                durationMS: 180_000 + index * 1_000,
                popularity: 40 + index,
                artists: [TrackArtist(name: "Artist \(index % 3)")],
                album: TrackAlbum(id: "alb\(index % 4)"),
                type: .track
            )
        )
    }
}

private func sampleFeatures(count: Int) -> [String: AudioFeatures] {
    var table: [String: AudioFeatures] = [:]
    for index in 0..<count {
        table["t\(index)"] = AudioFeatures(
            id: "t\(index)",
            tempo: Double(180 - index * 5),
            energy: Double(index) / Double(count),
            danceability: 0.5,
            loudness: -6,
            valence: 0.4,
            acousticness: 0.2
        )
    }
    return table
}

private func makePlaylist(ownerID: String = "me", isPublic: Bool = false, description: String? = "Original") -> Playlist {
    Playlist(
        id: "p1", name: "Test Playlist", uri: "spotify:playlist:p1",
        owner: PlaylistOwner(id: ownerID, displayName: "Owner"),
        tracks: PlaylistTrackCount(total: 8),
        isPublic: isPublic, rawDescription: description
    )
}

@Suite("Track table model")
@MainActor
struct TrackTableModelTests {

    private func loadedModel(
        count: Int = 8,
        ownerID: String = "me",
        service: RecordingService? = nil,
        provider: (any AudioFeatureProviding)? = nil
    ) async -> (TrackTableModel, RecordingService) {
        let items = sampleItems(count: count)
        let resolvedService = service ?? RecordingService(items: items)
        let model = TrackTableModel(
            playlist: makePlaylist(ownerID: ownerID),
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
        let model = TrackTableModel(
            playlist: makePlaylist(),
            service: RecordingService(items: []),
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

    @Test("Tapping the active header reverses it; a different one starts ascending")
    func headerSelection() async {
        let (model, _) = await loadedModel()

        model.selectFromLegacyHeader(.attribute(.bpm))
        #expect(model.arrangement == .attribute(.bpm, .ascending))

        model.selectFromLegacyHeader(.attribute(.bpm))
        #expect(model.arrangement == .attribute(.bpm, .descending))

        model.selectFromLegacyHeader(.attribute(.energy))
        #expect(model.arrangement == .attribute(.energy, .ascending), "switching resets direction")
    }

    @Test("The position header still reverses the playlist on a second tap")
    func originalOrderHeaderReverses() async {
        let (model, _) = await loadedModel()

        model.selectFromLegacyHeader(.attribute(.bpm))
        model.selectFromLegacyHeader(.originalOrder)
        #expect(model.arrangement == .originalOrder)

        model.selectFromLegacyHeader(.originalOrder)
        #expect(model.arrangement == .attribute(.order, .descending))
        #expect(model.arrangedRows.map(\.originalIndex) == Array((0..<8).reversed()))
    }

    @Test("Artist separation and Shuffle have no direction to toggle")
    func directionlessArrangements() async {
        let (model, _) = await loadedModel()
        for basis in [Arrangement.Basis.artistSeparation, .shuffle] {
            model.selectFromLegacyHeader(basis)
            let once = model.arrangement
            model.selectFromLegacyHeader(basis)

            #expect(model.arrangement == once, "\(basis.name) has no direction to flip")
            #expect(model.arrangement.direction == nil)
        }
    }

    @Test("Re-selecting Shuffle reshuffles the rows")
    func shuffleReshuffles() async {
        let (model, _) = await loadedModel(count: 40)
        model.selectFromLegacyHeader(.shuffle)
        let first = model.arrangedRows.map(\.id)
        model.selectFromLegacyHeader(.shuffle)
        #expect(model.arrangedRows.map(\.id) != first)
    }

    @Test("Saving a new playlist names it after the Arrangement and writes the visible order")
    func saveNewPlaylist() async {
        let (model, service) = await loadedModel()
        model.apply(.attribute(.bpm, .ascending))
        await model.save(createNew: true)

        let created = await service.createdPlaylists
        #expect(created.count == 1)
        #expect(created.first?.name == "Test Playlist ordered by increasing BPM")
        #expect(created.first?.description == "Original - Sorted by increasing BPM with Sortify")

        let writes = await service.writes
        #expect(writes.count == 1)
        #expect(writes.first?.playlistID == "new-playlist")
        #expect(writes.first?.uris == model.arrangedRows.compactMap(\.savableURI))
    }

    @Test("Overwriting targets the original playlist and creates nothing")
    func overwrite() async {
        let (model, service) = await loadedModel()
        #expect(model.canOverwrite)

        model.apply(.attribute(.energy, .ascending))
        await model.save(createNew: false)

        #expect(await service.createdPlaylists.isEmpty)
        #expect(await service.writes.first?.playlistID == "p1")
    }

    @Test("Overwrite is not offered for a playlist owned by someone else")
    func overwriteHiddenForOthers() async {
        let (model, _) = await loadedModel(ownerID: "someone-else")
        #expect(!model.canOverwrite)
    }

    @Test("A successful save re-arms the gate only after another change")
    func saveResetsDirtyState() async {
        let (model, _) = await loadedModel()
        model.apply(.attribute(.bpm, .ascending))
        await model.save(createNew: true)

        #expect(!model.canSave, "what's on Spotify now matches what's on screen")

        model.apply(.attribute(.valence, .ascending))
        #expect(model.canSave)
    }

    @Test("A 403 on write is reported as a permissions problem, not a generic failure")
    func forbiddenWriteExplained() async {
        let items = sampleItems(count: 4)
        let service = RecordingService(items: items, failWrites: true)
        let (model, _) = await loadedModel(count: 4, service: service)

        model.apply(.attribute(.bpm, .ascending))
        await model.save(createNew: false)

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

        await model.save(createNew: true)

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

    @Test("When no features come back, the reason is surfaced instead of silently blank columns")
    func featureNoticeSurfaced() async {
        let (model, _) = await loadedModel(
            provider: StubFeatureProvider(table: [:], reason: "Nothing found for this playlist.")
        )
        #expect(model.featureNotice == "Nothing found for this playlist.")
        #expect(model.rows.allSatisfy { $0.features == nil })
        #expect(model.phase == .ready, "the table still works without acoustic data")
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
    /// from, so it carries its own — without that, the artwork row in ticket 03
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
