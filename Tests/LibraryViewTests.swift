import Foundation
import Testing

@Suite("Library order and layout")
struct LibraryViewTests {

    private func playlist(_ name: String, tracks: Int) -> Playlist {
        Playlist(
            id: name,
            name: name,
            uri: "spotify:playlist:\(name)",
            owner: PlaylistOwner(id: "me"),
            images: nil,
            tracks: PlaylistTrackCount(total: tracks),
            collaborative: false,
            isPublic: true,
            rawDescription: nil
        )
    }

    private var sample: [Playlist] {
        [playlist("Zebra", tracks: 5), playlist("apple", tracks: 40), playlist("Mango", tracks: 40)]
    }

    @Test("Recents keeps the order the service returned")
    func recentsIsUntouched() {
        #expect(LibraryOrder.recents.apply(to: sample).map(\.name) == ["Zebra", "apple", "Mango"])
    }

    /// Case matters here: a plain `<` on Strings puts every capitalised name
    /// above every lowercase one, so "apple" would sort after "Zebra" and the
    /// list would look broken to anyone whose playlists aren't all capitalised.
    @Test("Name ignores case")
    func nameIgnoresCase() {
        #expect(LibraryOrder.name.apply(to: sample).map(\.name) == ["apple", "Mango", "Zebra"])
    }

    @Test("Track count puts the largest first and breaks ties by name")
    func sizeOrdersLargestFirst() {
        #expect(LibraryOrder.size.apply(to: sample).map(\.name) == ["apple", "Mango", "Zebra"])
    }

    @Test("Every order leaves the set of playlists unchanged")
    func ordersArePermutations() {
        for order in LibraryOrder.allCases {
            let result = order.apply(to: sample)
            #expect(Set(result.map(\.id)) == Set(sample.map(\.id)))
            #expect(result.count == sample.count)
        }
    }

    @Test("Ordering an empty library is empty rather than a crash")
    func emptyLibrary() {
        for order in LibraryOrder.allCases {
            #expect(order.apply(to: []).isEmpty)
        }
    }

    /// `toggled` and `nextLabel` used to live here and were tested here. Both
    /// were binary by construction - an involution and a "switch to the other
    /// one" label - and neither had any meaning once a third layout existed.
    /// Neither was referenced by a view, so they went rather than being given
    /// an arbitrary three-way definition.
    @Test("Every layout names itself and says how wide it is")
    func layoutsDescribeThemselves() {
        for layout in LibraryLayout.allCases {
            #expect(!layout.label.isEmpty)
            #expect(!layout.symbolName.isEmpty)
        }
        #expect(LibraryLayout.gridTwo.columns == 2)
        #expect(LibraryLayout.grid.columns == 3)
        #expect(LibraryLayout.list.columns == nil)
    }

    /// The picker is driven by `allCases`, so a layout missing from it is a
    /// layout no one can choose.
    @Test("All three layouts are offered")
    func everyLayoutIsReachable() {
        #expect(LibraryLayout.allCases.count == 3)
        #expect(Set(LibraryLayout.allCases.map(\.label)).count == 3)
    }

    // MARK: - Preferences

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "library-tests-\(name)")!
        defaults.removePersistentDomain(forName: "library-tests-\(name)")
        return defaults
    }

    @Test("Preferences round-trip and survive a fresh reader")
    func preferencesRoundTrip() {
        let defaults = isolatedDefaults("roundtrip")
        let preferences = LibraryPreferences(defaults: defaults)

        #expect(preferences.order == .recents)
        #expect(preferences.layout == .gridTwo)

        preferences.order = .name
        preferences.layout = .list

        let reread = LibraryPreferences(defaults: defaults)
        #expect(reread.order == .name)
        #expect(reread.layout == .list)

        // The two-up layout arrived after the key was already in use, so its
        // raw value has to round-trip like the two that predate it.
        preferences.layout = .grid
        #expect(LibraryPreferences(defaults: defaults).layout == .grid)
    }

    /// A preference is not state: losing it is harmless, so a value that no
    /// longer parses must fall back rather than crash or persist as garbage.
    @Test("A stored value that no longer parses falls back to the default")
    func garbageFallsBack() {
        let defaults = isolatedDefaults("garbage")
        defaults.set("carousel", forKey: "library.layout")
        defaults.set("by-vibes", forKey: "library.order")

        let preferences = LibraryPreferences(defaults: defaults)
        #expect(preferences.layout == .gridTwo)
        #expect(preferences.order == .recents)
    }
}

@Suite("Empty states")
struct EmptyStateTests {

    /// The distinction the screens turn on: a search that matched nothing is a
    /// different situation from a category that holds nothing, and telling a
    /// user to clear a search they never typed is worse than saying nothing.
    @Test("Searching and filtering produce different words and different ways out")
    func searchAndFilterDiffer() {
        let searched = EmptyState.noPlaylistsMatch(hasSearch: true)
        let filtered = EmptyState.noPlaylistsMatch(hasSearch: false)

        #expect(searched.title != filtered.title)
        #expect(searched.message != filtered.message)
        #expect(searched.actionTitle == "Clear search")
        #expect(filtered.actionTitle == "Show all playlists")
    }

    @Test("A state with no way out offers no action")
    func statesWithoutAWayOut() {
        #expect(EmptyState.noPlaylists.actionTitle == nil)
        #expect(EmptyState.playlistEmpty.actionTitle == nil)
    }

    @Test("The filter state names how many tracks are being hidden")
    func filterStateCountsWhatItHides() {
        #expect(EmptyState.filterHidesEverything(total: 68).message.contains("68"))
    }

    @Test("Every state has a title, a message and a symbol")
    func everyStateIsComplete() {
        let states: [EmptyState] = [
            .noPlaylistsMatch(hasSearch: true),
            .noPlaylistsMatch(hasSearch: false),
            .noPlaylists,
            .playlistEmpty,
            .filterHidesEverything(total: 3),
        ]
        for state in states {
            #expect(!state.title.isEmpty)
            #expect(!state.symbolName.isEmpty)
            #expect(state.message.count > 20, "\(state) needs a sentence, not a fragment")
            #expect(state.spoken.contains(state.title))
        }
    }

    /// Product copy, and the dev asked for these gone throughout the app.
    ///
    /// The character is written as an escape rather than typed, so a repo-wide
    /// sweep for em dashes cannot rewrite the guard into a check for hyphens
    /// and leave the suite green while asserting nothing.
    @Test("No empty state uses an em dash")
    func noEmDashes() {
        let emDash = "\u{2014}"
        let states: [EmptyState] = [
            .noPlaylistsMatch(hasSearch: true),
            .noPlaylistsMatch(hasSearch: false),
            .noPlaylists,
            .playlistEmpty,
            .filterHidesEverything(total: 3),
        ]
        for state in states {
            #expect(!state.title.contains(emDash))
            #expect(!state.message.contains(emDash))
        }
    }
}

@Suite("Playlist filters")
struct PlaylistFilterTests {

    private func playlist(id: String, ownerID: String, collaborative: Bool = false) -> Playlist {
        Playlist(
            id: id,
            name: id,
            uri: "spotify:playlist:\(id)",
            owner: PlaylistOwner(id: ownerID),
            tracks: PlaylistTrackCount(total: 1),
            collaborative: collaborative
        )
    }

    /// Discover Weekly and the Daily Mixes.
    private var personalized: Playlist { playlist(id: "37i9dQZF1DXcBWIGoYBM5M", ownerID: "spotify") }
    private var editorial: Playlist { playlist(id: "editorial", ownerID: "spotify") }
    private var mine: Playlist { playlist(id: "mine", ownerID: "me") }

    @Test("Personalized is no longer offered as a chip")
    func personalizedChipIsGone() {
        #expect(!PlaylistFilter.allCases.contains(.category(.personalized)))
    }

    /// Removing the chip must not strand the playlists behind it. This is the
    /// assertion that makes the removal safe rather than merely tidy.
    @Test("A personalized playlist is still reachable, under Spotify")
    func personalizedIsStillReachable() {
        #expect(PlaylistFilter.category(.spotify).matches(personalized, currentUserID: "me"))
        #expect(PlaylistFilter.all.matches(personalized, currentUserID: "me"))

        // And it is reachable from some chip that actually exists.
        let reachable = PlaylistFilter.allCases.contains { $0.matches(personalized, currentUserID: "me") }
        #expect(reachable)
    }

    @Test("Spotify's own editorial playlists still match Spotify")
    func editorialStillMatches() {
        #expect(PlaylistFilter.category(.spotify).matches(editorial, currentUserID: "me"))
    }

    @Test("Widening Spotify did not swallow anyone else's playlists")
    func spotifyDidNotWiden() {
        #expect(!PlaylistFilter.category(.spotify).matches(mine, currentUserID: "me"))
        #expect(PlaylistFilter.category(.mine).matches(mine, currentUserID: "me"))
        #expect(!PlaylistFilter.category(.mine).matches(personalized, currentUserID: "me"))
    }

    /// Every playlist must be findable from at least one chip, whatever it is.
    @Test("No playlist falls through every filter")
    func nothingIsStranded() {
        for target in [personalized, editorial, mine, playlist(id: "other", ownerID: "ada")] {
            let reachable = PlaylistFilter.allCases.contains { $0.matches(target, currentUserID: "me") }
            #expect(reachable, "\(target.id) is invisible under every chip")
        }
    }

    /// Every fixture above takes `collaborative: false`, so until this existed
    /// the Collaborative chip was never once exercised - which is part of why a
    /// missing OAuth scope could hide every shared playlist without a single
    /// test noticing.
    @Test("Collaborative matches on the flag, whoever owns the playlist")
    func collaborativeMatchesEitherOwner() {
        let ownedByMe = playlist(id: "kitchen", ownerID: "me", collaborative: true)
        let ownedBySam = playlist(id: "roadtrip", ownerID: "sam", collaborative: true)

        #expect(PlaylistFilter.collaborative.matches(ownedByMe, currentUserID: "me"))
        #expect(PlaylistFilter.collaborative.matches(ownedBySam, currentUserID: "me"))
        #expect(!PlaylistFilter.collaborative.matches(mine, currentUserID: "me"))

        // Collaboration is an axis, not a category: a shared playlist you own
        // is still yours, and one Sam owns is still someone else's.
        #expect(PlaylistFilter.category(.mine).matches(ownedByMe, currentUserID: "me"))
        #expect(PlaylistFilter.category(.other).matches(ownedBySam, currentUserID: "me"))
    }
}

@Suite("OAuth scopes")
struct ScopeTests {

    /// Nothing asserted on the scopes before, which is exactly how a missing
    /// one survived: `playlist-read-collaborative` is not something any decode
    /// path or model test can observe. Without it Spotify omits playlists
    /// shared with the listener from `/me/playlists` entirely.
    @Test("Reading collaborative playlists is requested")
    func collaborativeScopeIsRequested() {
        #expect(SpotifyAuthConfig.requiredScopes.contains("playlist-read-collaborative"))
    }

    @Test("The scopes cover reading and writing, and nothing else")
    func scopesAreMinimal() {
        #expect(Set(SpotifyAuthConfig.requiredScopes) == [
            "playlist-read-private",
            "playlist-read-collaborative",
            "playlist-modify-private",
            "playlist-modify-public",
        ])
    }

    /// A token stored before the field existed decodes with nil, and nil has to
    /// mean "does not grant" - reading it as "grants everything" would leave the
    /// listener with no prompt and no shared playlists.
    @Test("A token that predates the field grants nothing")
    func tokensPredatingTheFieldGrantNothing() {
        let old = SpotifyTokens(accessToken: "a", refreshToken: "r", expiresAt: .distantFuture)
        #expect(!old.grants("playlist-read-collaborative"))

        let granted = SpotifyTokens(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: .distantFuture,
            grantedScopes: ["playlist-read-private", "playlist-read-collaborative"]
        )
        #expect(granted.grants("playlist-read-collaborative"))
        #expect(!granted.grants("playlist-modify-public"))
    }
}
