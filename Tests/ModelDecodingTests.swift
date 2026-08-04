import Foundation
import Testing

@Suite("Spotify payload decoding")
struct ModelDecodingTests {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    @Test("The legacy `tracks` spelling of a playlist still decodes")
    func legacyPlaylistShape() throws {
        let playlist = try decode(Playlist.self, """
        {
          "id": "abc", "name": "Old Shape", "uri": "spotify:playlist:abc",
          "owner": {"id": "me", "display_name": "Me"},
          "tracks": {"total": 42},
          "collaborative": false, "public": true, "description": "hi"
        }
        """)
        #expect(playlist.tracks.total == 42)
        #expect(playlist.cleanDescription == "hi")
        #expect(playlist.isPublic == true)
    }

    @Test("The February 2026 `items` spelling of a playlist decodes to the same model")
    func modernPlaylistShape() throws {
        let playlist = try decode(Playlist.self, """
        {
          "id": "abc", "name": "New Shape", "uri": "spotify:playlist:abc",
          "owner": {"id": "me"},
          "items": {"total": 7},
          "collaborative": true, "public": null, "description": null
        }
        """)
        #expect(playlist.tracks.total == 7)
        #expect(playlist.collaborative)
        #expect(playlist.isPublic == nil)
        #expect(playlist.cleanDescription == nil)
    }

    @Test("Spotify's literal \"null\" description string is treated as absent")
    func literalNullDescription() throws {
        let playlist = try decode(Playlist.self, """
        {"id":"a","name":"n","uri":"u","owner":{"id":"o"},"tracks":{"total":1},
         "collaborative":false,"description":"null"}
        """)
        #expect(playlist.cleanDescription == nil)
    }

    @Test("A playlist entry decodes from either `track` or `item`")
    func playlistItemBothSpellings() throws {
        let legacy = try decode(PlaylistItem.self, """
        {"added_at":"2024-01-01T00:00:00Z","is_local":false,
         "track":{"id":"t1","name":"Legacy","type":"track","duration_ms":1000}}
        """)
        #expect(legacy.track?.name == "Legacy")

        let modern = try decode(PlaylistItem.self, """
        {"added_at":"2024-01-01T00:00:00Z","is_local":false,
         "item":{"id":"t1","name":"Modern","type":"track","duration_ms":1000}}
        """)
        #expect(modern.track?.name == "Modern")
    }

    @Test("An episode decodes with no artists and is flagged as one")
    func episodeShape() throws {
        let item = try decode(PlaylistItem.self, """
        {"added_at":null,"track":{"id":"e1","name":"Ep 12","type":"episode","duration_ms":1800000}}
        """)
        #expect(item.track?.isEpisode == true)
        #expect(item.track?.primaryArtistName == nil)
    }

    @Test("Missing `popularity` — removed for new dev-mode apps — decodes as nil, not zero")
    func missingPopularity() throws {
        let playable = try decode(Playable.self, """
        {"id":"t1","name":"No Pop","type":"track","duration_ms":1000}
        """)
        #expect(playable.popularity == nil)
    }

    @Test("A paged response exposes its cursor and total")
    func pagingShape() throws {
        let page = try decode(Page<PlaylistItem>.self, """
        {"items":[{"track":{"id":"t1","name":"A","type":"track"}}],
         "next":"https://api.spotify.com/v1/playlists/x/items?offset=50","total":120}
        """)
        #expect(page.items.count == 1)
        #expect(page.total == 120)
        #expect(page.next != nil)
    }
}

@Suite("Playlist classification")
struct PlaylistClassificationTests {

    private func playlist(id: String = "p", ownerID: String) -> Playlist {
        Playlist(
            id: id, name: "P", uri: "spotify:playlist:\(id)",
            owner: PlaylistOwner(id: ownerID), tracks: PlaylistTrackCount(total: 1)
        )
    }

    @Test("Playlists are bucketed by owner, with the algorithmic prefix winning")
    func categories() {
        #expect(playlist(ownerID: "me").category(currentUserID: "me") == .mine)
        #expect(playlist(ownerID: "spotify").category(currentUserID: "me") == .spotify)
        #expect(playlist(ownerID: "sam").category(currentUserID: "me") == .other)
        #expect(
            playlist(id: "37i9dQZF1DXcBWIGoYBM5M", ownerID: "me").category(currentUserID: "me") == .personalized,
            "the algorithmic prefix must outrank ownership"
        )
    }

    @Test("Only playlists you own and that aren't algorithmic can be overwritten")
    func writability() {
        #expect(playlist(ownerID: "me").isWritable(byUserID: "me"))
        #expect(!playlist(ownerID: "sam").isWritable(byUserID: "me"))
        #expect(!playlist(ownerID: "me").isWritable(byUserID: nil))
        #expect(
            !playlist(id: "37i9dQZF1DXcBWIGoYBM5M", ownerID: "me").isWritable(byUserID: "me"),
            "Discover Weekly reports you as owner but always rejects writes"
        )
    }

    @Test("The card image is the smallest one still sharp at retina card size")
    func cardImageSelection() {
        let playlist = Playlist(
            id: "p", name: "P", uri: "u", owner: PlaylistOwner(id: "o"),
            images: [
                SpotifyImage(url: "https://x/64", width: 64, height: 64),
                SpotifyImage(url: "https://x/640", width: 640, height: 640),
                SpotifyImage(url: "https://x/300", width: 300, height: 300),
            ],
            tracks: PlaylistTrackCount(total: 1)
        )
        #expect(playlist.cardImageURL?.absoluteString == "https://x/300")
    }
}

@Suite("PKCE")
struct PKCETests {

    @Test("Verifiers are within the RFC 7636 length range and use only unreserved characters")
    func verifierShape() {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        for length in [43, 64, 128] {
            let verifier = PKCE.codeVerifier(length: length)
            #expect(verifier.count == length)
            #expect(verifier.unicodeScalars.allSatisfy(allowed.contains))
        }
    }

    @Test("Two verifiers are never the same")
    func verifiersAreUnique() {
        let verifiers = Set((0..<50).map { _ in PKCE.codeVerifier() })
        #expect(verifiers.count == 50)
    }

    @Test("The challenge is base64url of SHA-256, with no padding or URL-unsafe characters")
    func challengeEncoding() {
        let challenge = PKCE.codeChallenge(for: "abc123")
        #expect(!challenge.contains("="))
        #expect(!challenge.contains("+"))
        #expect(!challenge.contains("/"))
        // SHA-256 is 32 bytes, which is 43 base64 characters once padding is stripped.
        #expect(challenge.count == 43)
    }

    @Test("The same verifier always produces the same challenge")
    func challengeIsDeterministic() {
        #expect(PKCE.codeChallenge(for: "fixed-verifier") == PKCE.codeChallenge(for: "fixed-verifier"))
        #expect(PKCE.codeChallenge(for: "a") != PKCE.codeChallenge(for: "b"))
    }
}

@Suite("Token freshness")
struct TokenTests {

    @Test("A token expiring inside the next minute is already considered stale")
    func expiryMargin() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let comfortable = SpotifyTokens(accessToken: "a", refreshToken: "r", expiresAt: now.addingTimeInterval(300))
        #expect(comfortable.isFresh(now: now))

        let almostGone = SpotifyTokens(accessToken: "a", refreshToken: "r", expiresAt: now.addingTimeInterval(30))
        #expect(!almostGone.isFresh(now: now), "a token with 30s left would die mid-request")

        let expired = SpotifyTokens(accessToken: "a", refreshToken: "r", expiresAt: now.addingTimeInterval(-1))
        #expect(!expired.isFresh(now: now))
    }

    @Test("The in-memory store round-trips and clears")
    func inMemoryStore() {
        let store = InMemoryTokenStore()
        #expect(store.load() == nil)

        let tokens = SpotifyTokens(accessToken: "a", refreshToken: "r", expiresAt: Date())
        store.save(tokens)
        #expect(store.load() == tokens)

        store.clear()
        #expect(store.load() == nil)
    }
}
