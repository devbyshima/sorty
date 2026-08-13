import Foundation
import Testing

/// Where a release date comes from.
///
/// Every release date in the app read "Unavailable", and the reason was not that
/// Spotify withholds them: a track's own album carries `release_date`, the app
/// was decoding it, and then `enrich()` overwrote it with whatever a separate
/// `/albums` lookup returned. February 2026 removed batch `/albums` for newly
/// registered apps - which is every app Sorty asks a listener to create - so
/// what it returned was nothing, for everyone.
///
/// The guarantee these tests hold is therefore about *independence*: a release
/// date must survive a lookup that fails, and must not be replaced by one that
/// succeeds. The value being present is not enough to prove either.
@Suite("Release date source")
@MainActor
struct ReleaseDateSourceTests {

    private func loadedModel(
        service: RecordingMusicService,
        count: Int
    ) async -> TrackListModel {
        let model = TrackListModel(
            playlist: samplePlaylist(total: count),
            service: service,
            featureProvider: StubFeatureProvider(),
            currentUserID: "me"
        )
        await model.load()
        return model
    }

    /// The regression itself, in the exact shape a listener meets it: a Client ID
    /// that cannot call `/albums` at all.
    @Test("A refused album lookup costs no release dates")
    func refusedLookupCostsNothing() async {
        let service = RecordingMusicService(items: sampleItems(count: 6), albumsRefused: true)
        let model = await loadedModel(service: service, count: 6)

        #expect(model.phase == .ready)
        let everyRowHasADate = model.rows.allSatisfy { $0.albumReleaseDate != nil }
        #expect(
            everyRowHasADate,
            "the dates arrived with the playlist; a refused request cannot take them away"
        )
        for row in model.rows {
            #expect(model.detail(for: row).reading(for: .release)?.isAvailable == true)
        }
    }

    /// The Attribute has to be *arrangeable*, not merely printable. A date the
    /// sheet shows but the sorter can't rank would land every track in the
    /// unrankable group under a heading saying Sorty never read one.
    @Test("Arranging by release date ranks every track when the lookup is refused")
    func refusedLookupStillRanks() async {
        let service = RecordingMusicService(items: sampleItems(count: 6), albumsRefused: true)
        let model = await loadedModel(service: service, count: 6)
        model.apply(.attribute(.release, .ascending))

        #expect(model.rankedRows.count == 6)
        #expect(model.unrankableGroups.isEmpty)
        #expect(model.rankedRows.compactMap(\.albumReleaseDate) == model.rankedRows.compactMap(\.albumReleaseDate).sorted())
    }

    /// The request is not merely tolerated when it fails - in the normal case it
    /// never goes out. A playlist of 300 albums used to cost 15 batch calls, or
    /// 300 single ones on the degrade path, for values already in hand.
    @Test("No album is asked about when every track carries its date")
    func noRequestWhenNothingIsMissing() async {
        let service = RecordingMusicService(items: sampleItems(count: 8))
        _ = await loadedModel(service: service, count: 8)

        let requests = await service.albumRequests
        let askedAboutNothing = requests.allSatisfy { $0.isEmpty }
        #expect(askedAboutNothing, "asked about \(requests) with nothing missing")
    }

    /// The half of the fix that a present value cannot prove: a lookup that
    /// *works* must not overwrite what the track came with. Both sources hand
    /// back a date here, and the track's is the one that must win.
    @Test("A successful lookup never replaces the date the track came with")
    func lookupDoesNotOverwrite() async {
        let service = RecordingMusicService(items: sampleItems(count: 4), albumsHaveDates: true)
        let model = await loadedModel(service: service, count: 4)

        // The fixture's nested dates; the double's own answers are 2019-05-xx.
        #expect(model.rows.map(\.albumReleaseDate) == [
            "2010-01-14", "2011-02-14", "2012-03-14", "2013-04-14",
        ])
    }

    /// The lookup still earns its place. An album that genuinely arrived without
    /// a date is what it is now for, and dropping it would trade one silent
    /// absence for another.
    @Test("The lookup fills an album that arrived without a date")
    func lookupFillsAGenuineGap() async {
        let service = RecordingMusicService(
            items: sampleItems(count: 4, nestedReleaseDates: false),
            albumsHaveDates: true
        )
        let model = await loadedModel(service: service, count: 4)

        let everyDateCameFromTheLookup = model.rows.allSatisfy {
            $0.albumReleaseDate?.hasPrefix("2019-05") == true
        }
        #expect(everyDateCameFromTheLookup)
        let requests = await service.albumRequests
        let askedAboutSomething = requests.contains { !$0.isEmpty }
        #expect(askedAboutSomething, "the gap is exactly what the request is for")
    }

    /// A date-shaped absence. Release date sorts as text, so `""` would rank
    /// ahead of every real date instead of falling to the unrankable group -
    /// the same trap `validAddedAt` guards for the 1970 epoch.
    @Test("An empty release date is no date, not the earliest one")
    func emptyReleaseDateIsNoDate() async {
        let items = [
            PlaylistItem(
                addedAt: "2024-01-01T00:00:00Z",
                isLocal: true,
                track: Playable(
                    id: "local", name: "A local file", uri: nil, durationMS: 200_000,
                    artists: [TrackArtist(name: "Someone")],
                    album: TrackAlbum(id: nil, name: "", releaseDate: ""), type: .track
                )
            ),
            PlaylistItem(
                addedAt: "2024-01-02T00:00:00Z",
                isLocal: false,
                track: Playable(
                    id: "t1", name: "A real track", uri: "spotify:track:t1", durationMS: 200_000,
                    artists: [TrackArtist(name: "Someone")],
                    album: TrackAlbum(id: "alb1", releaseDate: "1999-04-01"), type: .track
                )
            ),
        ]
        let model = await loadedModel(
            service: RecordingMusicService(items: items, albumsRefused: true),
            count: items.count
        )
        model.apply(.attribute(.release, .ascending))

        #expect(model.rows[0].albumReleaseDate == nil)
        #expect(model.detail(for: model.rows[0]).reading(for: .release)?.isAvailable == false)
        #expect(model.rankedRows.map(\.playable.name) == ["A real track"])
        #expect(model.unrankableGroups.flatMap(\.rows).map(\.playable.name) == ["A local file"])
    }
}
