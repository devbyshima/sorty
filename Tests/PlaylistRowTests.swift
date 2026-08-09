import Foundation
import Testing

/// What a playlist row says. The badge rules are the reason this is testable
/// rather than inline: one of them is a promise about the *next* screen.
@Suite("Playlist rows")
struct PlaylistRowTests {

    private func playlist(
        id: String = "p1",
        name: String = "Long Run",
        ownerID: String = "me",
        total: Int = 68,
        collaborative: Bool = false
    ) -> Playlist {
        Playlist(
            id: id, name: name, uri: "spotify:playlist:\(id)",
            owner: PlaylistOwner(id: ownerID),
            tracks: PlaylistTrackCount(total: total),
            collaborative: collaborative
        )
    }

    @Test("A row names the playlist and how much is in it")
    func namesAndCounts() {
        let text = PlaylistRowText(playlist: playlist(), currentUserID: "me")
        #expect(text.name == "Long Run")
        #expect(text.trackCount == "68 tracks")
        #expect(text.badges.isEmpty, "an ordinary playlist of yours carries no mark")
    }

    @Test("One track is one track")
    func singularCount() {
        let text = PlaylistRowText(playlist: playlist(total: 1), currentUserID: "me")
        #expect(text.trackCount == "1 track")
    }

    /// The badge exists so the answer arrives before the question. Deriving it
    /// from the same predicates the next screen uses is what keeps the two from
    /// disagreeing: a playlist that cannot be overwritten always says so, in
    /// whichever of the two ways applies to it.
    @Test("Nothing unwritable reaches a row unmarked")
    func everyUnwritablePlaylistIsMarked() {
        let cases: [(Playlist, Bool)] = [
            (playlist(), true),
            (playlist(ownerID: "someone-else"), false),
            (playlist(ownerID: "sam", collaborative: true), false),
            (playlist(id: "37i9dQZF-weekly", name: "Discover Weekly"), false),
            (playlist(name: "Today's Top Hits", ownerID: "spotify"), false),
        ]
        for (playlist, isWritable) in cases {
            let text = PlaylistRowText(playlist: playlist, currentUserID: "me")
            let marked = text.badges.contains(.readOnly) || text.badges.contains(.cantOpen)
            #expect(
                marked == !isWritable,
                "\(playlist.name) - the row must not promise what the save screen withdraws"
            )
            #expect(playlist.isWritable(byUserID: "me") == isWritable)
        }
    }

    /// The two marks answer different questions, and the more final one wins:
    /// telling someone Overwrite will be missing from a screen they can never
    /// reach is noise in front of the fact that matters.
    @Test("A playlist that never opens says that instead of read-only")
    func cantOpenReplacesReadOnly() {
        let theirs = PlaylistRowText(playlist: playlist(ownerID: "sam"), currentUserID: "me")
        #expect(theirs.badges == [.cantOpen])

        let weekly = PlaylistRowText(
            playlist: playlist(id: "37i9dQZF-weekly", name: "Discover Weekly"), currentUserID: "me"
        )
        #expect(weekly.badges == [.cantOpen])
    }

    /// A playlist can be collaborative *and* yours to overwrite - the two marks
    /// answer different questions, so neither implies the other. Shared with you
    /// is the case that keeps `readOnly` alive: Spotify opens it, Sorty still
    /// won't write over someone else's playlist.
    @Test("Collaborative and read-only are independent")
    func badgesAreIndependent() {
        #expect(
            PlaylistRowText(playlist: playlist(collaborative: true), currentUserID: "me").badges
                == [.collaborative]
        )
        #expect(
            PlaylistRowText(
                playlist: playlist(ownerID: "sam", collaborative: true), currentUserID: "me"
            ).badges == [.collaborative, .readOnly]
        )
    }

    /// Signed out there is no owner to compare against, so nothing is writable
    /// - and the rows say so rather than implying an Overwrite that isn't
    /// coming.
    @Test("With no account every playlist reads as read-only")
    func signedOutMarksEverything() {
        let text = PlaylistRowText(playlist: playlist(), currentUserID: nil)
        #expect(text.badges == [.readOnly])
    }

    @Test("A row is spoken as one sentence, marks included")
    func spokenAsOneSentence() {
        #expect(
            PlaylistRowText(playlist: playlist(), currentUserID: "me").spoken
                == "Long Run, 68 tracks."
        )
        #expect(
            PlaylistRowText(playlist: playlist(ownerID: "sam", collaborative: true), currentUserID: "me")
                .spoken == "Long Run, 68 tracks, Collaborative, Read-only."
        )
    }

    /// The demo catalogue is what every screenshot is judged against, so the
    /// spread of marks in it has to be a real one.
    @Test("The demo catalogue exercises every badge combination")
    func demoCatalogueCoversTheBadges() {
        let texts = DemoCatalog.shared.playlists.map {
            PlaylistRowText(playlist: $0, currentUserID: DemoCatalog.userID)
        }
        #expect(texts.contains { $0.badges.isEmpty })
        #expect(texts.contains { $0.badges == [.collaborative] })
        #expect(texts.contains { $0.badges == [.collaborative, .readOnly] })
        #expect(texts.contains { $0.badges == [.cantOpen] })
    }

    /// Spotify sends no count for a playlist it will not open, and a row that
    /// filled the gap with "0 tracks" would be inventing the one fact it is
    /// there to report.
    @Test("A withheld count is said to be withheld, not counted as none")
    func withheldCountIsNotZero() {
        let theirs = Playlist(
            id: "p9", name: "Sam's", uri: "spotify:playlist:p9",
            owner: PlaylistOwner(id: "sam"),
            tracks: PlaylistTrackCount(total: 0),
            trackCountIsKnown: false
        )
        let text = PlaylistRowText(playlist: theirs, currentUserID: "me")
        #expect(text.trackCount == "Track count hidden")
        #expect(!text.trackCount.contains("0 tracks"))
        #expect(text.spoken == "Sam's, Track count hidden, Can't open.")
    }
}
