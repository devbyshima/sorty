import Foundation
import Testing

/// Spotify answers most refusals with a bare 403 and the word "Forbidden",
/// which reached the screen verbatim. These pin the replacement: the status
/// alone never says which refusal it is, so the playlist has to be read too.
@Suite("Load failure copy")
struct LoadFailureTests {

    private func playlist(
        id: String = "p1",
        ownerID: String,
        ownerName: String? = nil
    ) -> Playlist {
        Playlist(
            id: id,
            name: "Test",
            uri: "spotify:playlist:\(id)",
            owner: PlaylistOwner(id: ownerID, displayName: ownerName),
            images: nil,
            tracks: PlaylistTrackCount(total: 10),
            collaborative: false,
            isPublic: true,
            rawDescription: nil
        )
    }

    private let forbidden = SpotifyAPIError.http(status: 403, message: "Forbidden")

    @Test("The raw word Forbidden never reaches the screen")
    func forbiddenIsNeverShownRaw() {
        let cases = [
            playlist(ownerID: "spotify"),
            playlist(id: "37i9dQZF1DX", ownerID: "spotify"),
            playlist(ownerID: "someone-else", ownerName: "Ada"),
            playlist(ownerID: "me"),
        ]
        for target in cases {
            let message = LoadFailure.message(for: forbidden, playlist: target, currentUserID: "me")
            #expect(!message.lowercased().contains("forbidden"), "leaked the raw status for \(target.id)")
            #expect(message.count > 40, "\(target.id) got a fragment rather than an explanation")
        }
    }

    /// The single most likely cause: since November 2024 Spotify blocks new
    /// apps from reading its algorithmic playlists.
    @Test("A personalized playlist is named as Spotify's own restriction")
    func personalizedExplainsTheRestriction() {
        let discoverWeekly = playlist(id: "37i9dQZF1DXcBWIGoYBM5M", ownerID: "spotify")
        let message = LoadFailure.message(for: forbidden, playlist: discoverWeekly, currentUserID: "me")
        #expect(message.contains("Discover Weekly"))
        #expect(message.contains("2024"))
    }

    @Test("Another listener's playlist names who owns it")
    func otherOwnerIsNamed() {
        let theirs = playlist(ownerID: "ada99", ownerName: "Ada")
        #expect(LoadFailure.message(for: forbidden, playlist: theirs, currentUserID: "me").contains("Ada"))
    }

    /// The four cases must not collapse into one sentence with a noun swapped:
    /// each is a different situation with a different implication.
    @Test("Each kind of refusal reads differently")
    func categoriesDiffer() {
        let messages = [
            LoadFailure.message(for: forbidden, playlist: playlist(id: "37i9dQZF1", ownerID: "spotify"), currentUserID: "me"),
            LoadFailure.message(for: forbidden, playlist: playlist(ownerID: "spotify"), currentUserID: "me"),
            LoadFailure.message(for: forbidden, playlist: playlist(ownerID: "ada"), currentUserID: "me"),
            LoadFailure.message(for: forbidden, playlist: playlist(ownerID: "me"), currentUserID: "me"),
        ]
        #expect(Set(messages).count == 4)
    }

    /// A Try Again button that only ever reproduces the same refusal is worse
    /// than no button. A rule refuses every request alike; a glitch on your own
    /// playlist might not.
    @Test("Retry is offered only where retrying could work")
    func retryIsOfferedHonestly() {
        #expect(!LoadFailure.isWorthRetrying(forbidden, playlist: playlist(ownerID: "spotify"), currentUserID: "me"))
        #expect(!LoadFailure.isWorthRetrying(forbidden, playlist: playlist(ownerID: "ada"), currentUserID: "me"))
        #expect(LoadFailure.isWorthRetrying(forbidden, playlist: playlist(ownerID: "me"), currentUserID: "me"))
    }

    @Test("A network error keeps its own wording and stays retryable")
    func transportErrorsPassThrough() {
        let offline = SpotifyAPIError.transport(URLError(.notConnectedToInternet))
        let target = playlist(ownerID: "spotify")
        #expect(LoadFailure.message(for: offline, playlist: target, currentUserID: "me") == offline.localizedDescription)
        #expect(LoadFailure.isWorthRetrying(offline, playlist: target, currentUserID: "me"))
    }

    /// 404 is the other spelling of the same refusal, and must not fall through
    /// to a raw "Spotify returned an error (404)".
    @Test("404 is treated as the same refusal as 403")
    func notFoundIsHandledToo() {
        let missing = SpotifyAPIError.http(status: 404, message: nil)
        let target = playlist(ownerID: "spotify")
        #expect(LoadFailure.message(for: missing, playlist: target, currentUserID: "me").contains("editorial"))
    }

    /// Written as an escape rather than as the character, so a repo-wide sweep
    /// for em dashes cannot quietly rewrite the guard into a check for hyphens
    /// and leave the suite green while asserting nothing.
    @Test("No failure message uses an em dash")
    func noEmDashes() {
        let emDash = "\u{2014}"
        let targets = [
            playlist(id: "37i9dQZF1", ownerID: "spotify"),
            playlist(ownerID: "spotify"),
            playlist(ownerID: "ada"),
            playlist(ownerID: "me"),
        ]
        for target in targets {
            #expect(!LoadFailure.message(for: forbidden, playlist: target, currentUserID: "me").contains(emDash))
        }
    }
}
