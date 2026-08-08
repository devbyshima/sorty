import Foundation
import Testing

/// What the playlist screen says beneath the name.
///
/// Two of these rules exist because the header is read while the screen is
/// still filling: the count changes source mid-load, and the running time is
/// not knowable from the listing at all. The rest are the ADR-0008 rules about
/// a count Spotify never sent.
@Suite("Playlist header")
struct PlaylistHeaderTests {

    private func playlist(
        ownerID: String = "me",
        ownerName: String? = "Demo Listener",
        total: Int = 68,
        countIsKnown: Bool = true
    ) -> Playlist {
        Playlist(
            id: "p1", name: "Long Run", uri: "spotify:playlist:p1",
            owner: PlaylistOwner(id: ownerID, displayName: ownerName),
            tracks: PlaylistTrackCount(total: total),
            trackCountIsKnown: countIsKnown
        )
    }

    private func row(_ index: Int, ms: Int?, featureMS: Int? = nil) -> TrackRow {
        TrackRow(
            originalIndex: index,
            playable: Playable(
                id: "t\(index)",
                name: "Track \(index)",
                durationMS: ms
            ),
            features: featureMS.map { AudioFeatures(id: "t\(index)", durationMS: $0) }
        )
    }

    // MARK: - Owner

    @Test("The owner is named on their own, not folded into the line below")
    func ownerStandsAlone() {
        let text = PlaylistHeaderText(playlist: playlist(), loadedCount: 0, visible: [], isFiltered: false)
        #expect(text.owner == "Demo Listener")
        #expect(text.detail == "68 tracks", "the owner is drawn beside the avatar, not here")
    }

    @Test("An owner Spotify did not name is absent rather than blank")
    func namelessOwner() {
        let text = PlaylistHeaderText(
            playlist: playlist(ownerID: "", ownerName: nil),
            loadedCount: 0, visible: [], isFiltered: false
        )
        #expect(text.owner == nil)
        #expect(text.spoken == "68 tracks", "no leading full stop where a name would have been")
    }

    /// The avatar is a circle whatever happens, so the fallback has to produce
    /// something for every account name Spotify permits - including the ones
    /// that are an email address or a bare user id.
    @Test("Initials come from any shape of account name")
    func initials() {
        let cases: [(String?, String)] = [
            ("Demo Listener", "DL"),
            ("Sam", "S"),
            ("ada.lovelace", "AL"),
            ("first_last", "FL"),
            ("Three Word Name", "TW"),
            ("31jd7kfmz", "3"),
            (nil, "?"),
            ("", "?"),
        ]
        for (name, expected) in cases {
            #expect(PlaylistHeaderText.initials(of: name?.isEmpty == true ? nil : name) == expected,
                    "initials of \(name ?? "nil")")
        }
    }

    // MARK: - Count

    @Test("The count comes from the listing before a load and from the rows after")
    func countSwitchesSource() {
        let before = PlaylistHeaderText(playlist: playlist(total: 68), loadedCount: 0, visible: [], isFiltered: false)
        #expect(before.tracks == "68 tracks")

        let rows = (0..<3).map { row($0, ms: 60_000) }
        let after = PlaylistHeaderText(playlist: playlist(total: 68), loadedCount: 3, visible: rows, isFiltered: false)
        #expect(after.tracks == "3 tracks", "what actually arrived wins over what the listing promised")
    }

    @Test("One track is one track")
    func singular() {
        let text = PlaylistHeaderText(playlist: playlist(total: 1), loadedCount: 0, visible: [], isFiltered: false)
        #expect(text.tracks == "1 track")
    }

    @Test("A filter says how much it is hiding")
    func filtered() {
        let rows = (0..<12).map { row($0, ms: 60_000) }
        let text = PlaylistHeaderText(playlist: playlist(), loadedCount: 68, visible: rows, isFiltered: true)
        #expect(text.tracks == "12 of 68 tracks")
    }

    /// ADR-0008. Spotify sends no contents object for a playlist the listener
    /// neither owns nor collaborates on, and the count lives inside it.
    @Test("A count Spotify withheld is not a count of zero")
    func withheldCount() {
        let text = PlaylistHeaderText(
            playlist: playlist(ownerID: "other", total: 0, countIsKnown: false),
            loadedCount: 0, visible: [], isFiltered: false
        )
        #expect(text.tracks == PlaylistRowText.hiddenTrackCount)
        #expect(text.tracks != "0 tracks")
    }

    @Test("Rows that arrive answer a count Spotify never sent")
    func withheldCountThenLoaded() {
        let rows = (0..<9).map { row($0, ms: 60_000) }
        let text = PlaylistHeaderText(
            playlist: playlist(total: 0, countIsKnown: false),
            loadedCount: 9, visible: rows, isFiltered: false
        )
        #expect(text.tracks == "9 tracks", "having them is better evidence than being told about them")
    }

    // MARK: - Running time

    @Test("There is no running time until something has loaded")
    func noDurationBeforeLoad() {
        let text = PlaylistHeaderText(playlist: playlist(), loadedCount: 0, visible: [], isFiltered: false)
        #expect(text.duration == nil, "the listing carries a count and no total duration")
        #expect(text.detail == "68 tracks")
    }

    @Test("Hours and minutes, not minutes and seconds")
    func formatsAsHoursAndMinutes() {
        let cases: [(Int, String?)] = [
            (0, nil),
            (30_000, "under a minute"),
            (60_000, "1m"),
            (41 * 60_000, "41m"),
            (60 * 60_000, "1h 0m"),
            (97 * 60_000, "1h 37m"),
            (247 * 60_000, "4h 7m"),
        ]
        for (ms, expected) in cases {
            #expect(PlaylistHeaderText.runningTime(of: ms == 0 ? [] : [row(0, ms: ms)]) == expected,
                    "\(ms)ms")
        }
    }

    /// The rows show the provider's length, so the total has to agree with what
    /// is on screen rather than with a second source.
    @Test("The feature length wins, matching what the rows print")
    func featureLengthWins() {
        let rows = [row(0, ms: 60_000, featureMS: 120_000)]
        #expect(PlaylistHeaderText.runningTime(of: rows) == "2m")
    }

    @Test("A track with no length at all costs the total nothing")
    func missingLengthIsNotZeroed() {
        let rows = [row(0, ms: 180_000), row(1, ms: nil), row(2, ms: 120_000)]
        #expect(PlaylistHeaderText.runningTime(of: rows) == "5m")
    }

    /// A filtered header says "12 of 68 tracks", so a duration measuring the 68
    /// would describe a different playlist from the count beside it.
    @Test("The running time measures what the count measures")
    func durationFollowsTheFilter() {
        let visible = (0..<2).map { row($0, ms: 60_000) }
        let text = PlaylistHeaderText(playlist: playlist(), loadedCount: 68, visible: visible, isFiltered: true)
        #expect(text.tracks == "2 of 68 tracks")
        #expect(text.duration == "2m")
        #expect(text.detail == "2 of 68 tracks · 2m")
    }
}
