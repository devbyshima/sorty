import Foundation
import Testing

/// Another listener's playlist, from the library listing to the screen that
/// opens when you tap it.
///
/// Since the February 2026 Development Mode migration, Get Playlist Items is
/// "only accessible for playlists owned by the current user or playlists the
/// user is a collaborator of" and answers 403 for anything else, and a playlist
/// the listener does not own arrives with no track count at all. Both facts
/// used to reach the app as something else: the missing count as an empty
/// playlist, which deleted every one of these from the library, and the 403 as
/// a sentence about permissions with nothing to do about it. See ADR-0008.
@Suite("Another listener's playlists")
@MainActor
struct OtherListenersPlaylistsTests {

    private func playlist(
        id: String = "p1",
        name: String = "Coffee House",
        ownerID: String,
        ownerName: String? = nil,
        collaborative: Bool = false,
        total: Int = 29,
        countIsKnown: Bool = true
    ) -> Playlist {
        Playlist(
            id: id, name: name, uri: "spotify:playlist:\(id)",
            owner: PlaylistOwner(id: ownerID, displayName: ownerName),
            tracks: PlaylistTrackCount(total: total),
            trackCountIsKnown: countIsKnown,
            collaborative: collaborative
        )
    }

    // MARK: - The rule

    @Test("Spotify opens a playlist for its owner and its collaborators, and no one else")
    func readabilityFollowsOwnershipAndCollaboration() {
        #expect(playlist(ownerID: "me").contentsAreReadable(byUserID: "me"))
        #expect(playlist(ownerID: "sam", collaborative: true).contentsAreReadable(byUserID: "me"))
        #expect(!playlist(ownerID: "sam").contentsAreReadable(byUserID: "me"))
        #expect(!playlist(ownerID: "spotify").contentsAreReadable(byUserID: "me"))
        #expect(
            !playlist(id: "37i9dQZF1DXcBWIGoYBM5M", ownerID: "me").contentsAreReadable(byUserID: "me"),
            "Spotify reports the listener as owner of some algorithmic playlists and refuses them anyway"
        )
    }

    /// Not knowing is not a refusal. Blocking a request because the account
    /// hasn't loaded yet would turn a slow start into a permanent wall.
    @Test("An unknown listener or an unnamed owner is still worth asking about")
    func unknownIdentityIsNotARefusal() {
        #expect(playlist(ownerID: "sam").contentsAreReadable(byUserID: nil))
        #expect(playlist(ownerID: "").contentsAreReadable(byUserID: "me"))
    }

    /// This is the question `isWritable` cannot answer. The two were the same
    /// predicate in effect until Spotify stopped sending contents, and a
    /// playlist that never opens is a different thing from one that opens and
    /// can't be saved over.
    @Test("Readable and writable are different questions")
    func readabilityIsNotWritability() {
        let shared = playlist(ownerID: "sam", collaborative: true)
        #expect(shared.contentsAreReadable(byUserID: "me"))
        #expect(!shared.isWritable(byUserID: "me"))
    }

    // MARK: - The library listing

    /// The regression this whole change starts from: Spotify sends no count for
    /// a playlist it will not open, the library drops playlists with nothing in
    /// them, and reading "no count" as "no tracks" made every one of another
    /// listener's playlists vanish before it was ever drawn.
    @Test("A playlist whose count Spotify withheld is not an empty playlist")
    func withheldCountIsNotEmptiness() {
        #expect(!playlist(ownerID: "sam", total: 0, countIsKnown: false).isReportedEmpty)
        #expect(playlist(ownerID: "me", total: 0).isReportedEmpty)
        #expect(!playlist(ownerID: "me", total: 29).isReportedEmpty)
    }

    @Test("A listing entry with no contents object decodes as a count Spotify didn't send")
    func decodingAMissingCount() throws {
        let withheld = Data(#"{"id":"p1","name":"Sam's","owner":{"id":"sam"}}"#.utf8)
        let reported = Data(#"{"id":"p2","name":"Mine","owner":{"id":"me"},"items":{"total":0}}"#.utf8)

        let theirs = try JSONDecoder().decode(Playlist.self, from: withheld)
        #expect(!theirs.trackCountIsKnown)
        #expect(!theirs.isReportedEmpty, "no count is not a count of zero")

        let mine = try JSONDecoder().decode(Playlist.self, from: reported)
        #expect(mine.trackCountIsKnown)
        #expect(mine.isReportedEmpty)
    }

    /// A page of nothing and a page that withheld its contents decode to the
    /// same empty array and mean opposite things.
    @Test("An absent items array is told apart from an empty one")
    func absentItemsAreNotAnEmptyPage() throws {
        let empty = try JSONDecoder().decode(
            Page<PlaylistItem>.self, from: Data(#"{"items":[],"total":0}"#.utf8)
        )
        #expect(empty.carriedItems)
        #expect(empty.items.isEmpty)

        let withheld = try JSONDecoder().decode(
            Page<PlaylistItem>.self, from: Data(#"{"total":29}"#.utf8)
        )
        #expect(!withheld.carriedItems)
        #expect(withheld.items.isEmpty)
    }

    // MARK: - Opening one

    @Test("Opening another listener's playlist says so without asking Spotify")
    func theRefusalIsKnownInAdvance() async {
        let service = RecordingMusicService(items: sampleItems(count: 4))
        let model = TrackListModel(
            playlist: playlist(ownerID: "sam", ownerName: "Sam"),
            service: service,
            featureProvider: StubFeatureProvider(),
            currentUserID: "me"
        )

        await model.load()

        #expect(model.phase == .unavailable(.contentsWithheld(owner: "Sam")))
        #expect(!model.canRetryLoad, "a rule refuses the next request identically")
        #expect(
            await service.itemRequests.isEmpty,
            "the answer was in hand, and a request for it would spend a five-listener quota to be told 403"
        )
    }

    /// The same state from the other direction: a collaborator's invite
    /// withdrawn between the listing and the tap, which only Spotify can report.
    @Test("A refusal from the wire lands in the same state as one known in advance")
    func aWireRefusalReadsTheSame() async {
        let model = TrackListModel(
            playlist: playlist(ownerID: "sam", ownerName: "Sam", collaborative: true),
            service: RefusingMusicService(error: .http(status: 403, message: "Forbidden")),
            featureProvider: StubFeatureProvider(),
            currentUserID: "me"
        )

        await model.load()

        #expect(model.phase == .unavailable(.contentsWithheld(owner: "Sam")))
        #expect(!model.canRetryLoad)
    }

    /// The documented shape for a playlist the listener neither owns nor
    /// collaborates on is a 200 with the contents left out. Read as a decoding
    /// failure it became "Spotify sent a response Sorty couldn't read", which
    /// blames the app for a rule.
    @Test("Contents left out of a 200 are a refusal, not a broken response")
    func withheldContentsAreARefusal() async {
        let model = TrackListModel(
            playlist: playlist(ownerID: "sam", ownerName: "Sam", collaborative: true),
            service: RefusingMusicService(error: .contentsWithheld),
            featureProvider: StubFeatureProvider(),
            currentUserID: "me"
        )

        await model.load()

        #expect(model.phase == .unavailable(.contentsWithheld(owner: "Sam")))
    }

    @Test("A playlist shared with you still opens")
    func aSharedPlaylistStillLoads() async {
        let model = TrackListModel(
            playlist: playlist(ownerID: "sam", collaborative: true),
            service: RecordingMusicService(items: sampleItems(count: 4)),
            featureProvider: StubFeatureProvider(table: sampleFeatures(count: 4)),
            currentUserID: "me"
        )

        await model.load()

        #expect(model.phase == .ready)
        #expect(model.rows.count == 4)
    }

    // MARK: - What it says

    @Test("The words name the rule, name the owner, and name a way out")
    func theCopyIsUseful() {
        let message = EmptyState.contentsWithheld(owner: "Sam").message
        #expect(message.contains("Sam"))
        #expect(message.contains("collaborate"))
        #expect(message.contains("own"))
        #expect(!message.contains("\u{2014}"), "hyphen-only, repo-wide")

        #expect(message.contains("Ask Sam"), "the way out names who to ask")

        let anonymous = EmptyState.contentsWithheld(owner: nil).message
        #expect(!anonymous.contains("'s stays"), "no possessive with nobody to own it")
        #expect(anonymous.contains("this one"))
        #expect(anonymous.contains("whoever owns it"))
    }

    /// One rule, one wording. A listener who meets it in the library and again
    /// on the screen should not have to work out whether they are the same
    /// thing.
    @Test("The wire refusal and the known-in-advance one use the same sentence")
    func oneWordingForOneRule() {
        let theirs = playlist(ownerID: "sam", ownerName: "Sam")
        let fromTheWire = LoadFailure.message(
            for: SpotifyAPIError.http(status: 403, message: "Forbidden"),
            playlist: theirs,
            currentUserID: "me"
        )
        #expect(fromTheWire == EmptyState.contentsWithheld(owner: "Sam").message)
    }

    @Test("The way out is the link the rest of the app uses")
    func theWayOutIsSpotify() {
        #expect(EmptyState.contentsWithheld(owner: "Sam").actionTitle == "Open on Spotify")
    }
}

/// Refuses everything, so the states behind a refusal can be reached without a
/// network.
private actor RefusingMusicService: MusicService {
    let error: SpotifyAPIError

    init(error: SpotifyAPIError) { self.error = error }

    func currentUser() async throws -> SpotifyUser { throw error }
    func playlists(onBatch: @Sendable ([Playlist], Int?) async -> Void) async throws -> [Playlist] { [] }

    func playlistItems(
        playlistID: String,
        ownerID: String,
        onPage: @Sendable ([PlaylistItem], Int) async -> Void
    ) async throws -> [PlaylistItem] {
        throw error
    }

    func albums(ids: [String]) async throws -> [TrackAlbum] { [] }

    func createPlaylist(
        userID: String, name: String, isPublic: Bool, description: String
    ) async throws -> Playlist { throw error }

    func replaceTracks(playlistID: String, uris: [String]) async throws { throw error }
}
