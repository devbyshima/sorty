import Foundation
import Testing

/// The regression ADR-0018 starts from, pinned with the ids Spotify actually
/// uses.
///
/// `isPersonalized` read `37i9dQZF`, and Discover Weekly's id begins
/// `37i9dQZEVXc` - so the one playlist the predicate was named after had never
/// once satisfied it. It survived because **every fixture in this repository
/// used Today's Top Hits' id with Discover Weekly's name on it**, so the tests
/// and the code agreed with each other and with nothing on Spotify. Real ids,
/// here, for that reason.
@Suite("Spotify's own playlists")
struct SpotifyOwnedPlaylistTests {

    private func playlist(id: String, ownerID: String) -> Playlist {
        Playlist(
            id: id, name: "P", uri: "spotify:playlist:\(id)",
            owner: PlaylistOwner(id: ownerID), tracks: PlaylistTrackCount(total: 1)
        )
    }

    @Test("The ids Spotify actually uses are recognised as Spotify's")
    func realIDsAreRecognised() {
        let ids = [
            "37i9dQZEVXcJZyENOWUFo7",   // Discover Weekly
            "37i9dQZEVXbMDoHDwVN2tF",   // Top 50 - Global
            "37i9dQZF1DXcBWIGoYBM5M",   // Today's Top Hits
            "37i9dQZF1DX0XUsuxWHRQd",   // RapCaviar
            "37i9dQZF1E35mgCbeM97ny",   // a Daily Mix
        ]
        for id in ids {
            let target = playlist(id: id, ownerID: "spotify")
            #expect(target.isSpotifyGenerated, "\(id) fell outside the generated stem")
            #expect(target.category(currentUserID: "me") == .spotify, "\(id) fell out of Spotify's own")
            #expect(!target.isWritable(byUserID: "spotify"), "\(id) must never be overwritten")
        }
    }

    /// Spotify publishes under more than one account. A playlist of theirs used
    /// to fall through to `.other`, where the copy told the listener to ask
    /// whoever owns it to make it collaborative.
    @Test("Every account Spotify publishes under reads as Spotify")
    func publishingAccountsAreRecognised() {
        for owner in ["spotify", "spotifycharts", "spotifyusa", "spotify_uk_"] {
            #expect(playlist(id: "plain", ownerID: owner).category(currentUserID: "me") == .spotify)
        }
    }

    /// The cost of a prefix rather than a published list, stated so it is a
    /// decision rather than a surprise: nothing a listener can open stops
    /// opening, because what opens is decided by ownership alone.
    @Test("A listener whose id starts with spotify still reaches their playlists")
    func theOwnerPrefixCostIsBounded() {
        let theirs = playlist(id: "plain", ownerID: "spotifyfan99")
        #expect(theirs.contentsAreReadable(byUserID: "spotifyfan99"))
        #expect(PlaylistFilter.allCases.contains { $0.matches(theirs, currentUserID: "spotifyfan99") })
    }

    /// Readability is the documented rule now, and only that. The stem decides
    /// nothing that costs a request, because the stem is folklore.
    @Test("What opens is decided by ownership, not by an id prefix")
    func readabilityIsOwnershipAlone() {
        #expect(!playlist(id: "37i9dQZEVXcJZyENOWUFo7", ownerID: "spotify")
            .contentsAreReadable(byUserID: "me"))
        #expect(playlist(id: "37i9dQZEVXcJZyENOWUFo7", ownerID: "me")
            .contentsAreReadable(byUserID: "me"))
    }

    /// A plain user playlist must not be swept up by either half of the rule.
    @Test("Nobody else's playlist becomes Spotify's")
    func ordinaryPlaylistsAreUntouched() {
        let ada = playlist(id: "3cEYpjA9oz9GiPac4AsH4n", ownerID: "ada")
        #expect(!ada.isSpotifyOwned)
        #expect(ada.category(currentUserID: "me") == .other)

        let mine = playlist(id: "1DzUqOWiWfoHDBHYtCJIld", ownerID: "me")
        #expect(!mine.isSpotifyOwned)
        #expect(mine.category(currentUserID: "me") == .mine)
        #expect(mine.isWritable(byUserID: "me"))
    }
}

/// What the library says about playlists Spotify listed and would not name.
@Suite("Withheld from the listing")
struct LibraryNoticeTests {

    /// A footer explaining an absence of nothing is worse than silence.
    @Test("Nothing withheld says nothing")
    func silentWhenNothingIsMissing() {
        #expect(LibraryNotice.withheldFromListing(count: 0) == nil)
        #expect(LibraryNotice.withheldFromListing(count: -1) == nil)
    }

    @Test("One is singular and two are not")
    func countReadsCorrectly() throws {
        let one = try #require(LibraryNotice.withheldFromListing(count: 1))
        #expect(one.contains("1 playlist "))
        #expect(one.contains(" it,"))

        let several = try #require(LibraryNotice.withheldFromListing(count: 4))
        #expect(several.contains("4 playlists"))
        #expect(several.contains(" them,"))
    }

    /// **No action, deliberately.** There is no permission to grant and no
    /// button that would work, and offering one would be the app pretending it
    /// had a way out. If a future edit adds a call to action here, this is what
    /// should stop it.
    @Test("The notice offers no remedy, because there is none")
    func namesTheRuleAndNoFix() throws {
        let notice = try #require(LibraryNotice.withheldFromListing(count: 3))
        #expect(notice.contains("Discover Weekly"))
        for verb in ["Reconnect", "Try again", "Sign out", "Grant"] {
            #expect(!notice.contains(verb), "the notice must not offer \(verb)")
        }
    }
}
