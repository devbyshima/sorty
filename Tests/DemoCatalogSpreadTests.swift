import Foundation
import Testing

/// Demo Mode is the product's first impression (ADR-0003), so the numbers in it
/// have to look like measurements of real music rather than noise around a
/// midpoint. These are the properties that make an arrangement worth looking at:
/// if every track scores 50, arranging by that Attribute produces no visible
/// movement and the position bars in ticket 04 are all the same length.
@Suite("Demo catalogue spread")
struct DemoCatalogSpreadTests {

    /// The 0–100 Audio features, which share a scale and so share a threshold.
    ///
    /// Deliberately excludes `.pop`: popularity is Spotify's own metadata, not
    /// an Audio feature, and it is drawn uniformly across the whole range, so
    /// including it would pad every measurement here with a value that passes
    /// by construction.
    private static let scaled: [Attribute] = [.energy, .dance, .valence, .acoustic]

    /// Music only. An episode's "popularity" is not a measurement of anything,
    /// so counting it would let a run of zeroes stand in for real spread.
    private func rows(forPlaylist id: String, in catalog: DemoCatalog) -> [TrackRow] {
        catalog.items(forPlaylist: id).enumerated().compactMap { index, item in
            guard let playable = item.track, !playable.isEpisode else { return nil }
            var row = TrackRow(originalIndex: index, playable: playable, addedAt: item.addedAt)
            row.features = playable.id.flatMap { catalog.features(forTrackID: $0) }
            return row
        }
    }

    private func values(_ rows: [TrackRow], _ attribute: Attribute) -> [Double] {
        rows.compactMap { $0.numericValue(for: attribute) }
    }

    @Test("Across the library every 0–100 Attribute reaches both extremes")
    func libraryCoversFullRange() {
        let catalog = DemoCatalog()
        let all = catalog.playlists.flatMap { rows(forPlaylist: $0.id, in: catalog) }

        for attribute in Self.scaled {
            let observed = values(all, attribute)
            #expect(observed.min()! <= 15, "\(attribute) never gets low — min \(observed.min()!)")
            #expect(observed.max()! >= 85, "\(attribute) never gets high — max \(observed.max()!)")
        }
    }

    @Test("Within a single playlist the values still spread, not cluster")
    func eachPlaylistSpreads() {
        let catalog = DemoCatalog()

        for playlist in catalog.playlists {
            let playlistRows = rows(forPlaylist: playlist.id, in: catalog)
            for attribute in Self.scaled {
                let observed = values(playlistRows, attribute)
                let span = observed.max()! - observed.min()!
                #expect(
                    span >= 40,
                    "\(playlist.name) / \(attribute) spans only \(span) points — the position bar would be flat"
                )
            }
        }
    }

    private func standardDeviation(_ observed: [Double]) -> Double {
        let mean = observed.reduce(0, +) / Double(observed.count)
        return (observed.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(observed.count)).squareRoot()
    }

    /// The criterion is "span the range **instead of clustering in the
    /// middle**", and min/max cannot see clustering: two outliers satisfy it
    /// while every other track sits on 50. This measures the body of the
    /// distribution, across the library — which is the level the phrase is
    /// about, since a single playlist is *supposed* to have a character.
    @Test("Across the library, values fill the range rather than bunching mid-scale")
    func libraryIsNotConcentrated() {
        let catalog = DemoCatalog()
        let all = catalog.playlists.flatMap { rows(forPlaylist: $0.id, in: catalog) }

        for attribute in Self.scaled {
            let observed = values(all, attribute)

            #expect(
                standardDeviation(observed) >= 18,
                "\(attribute): SD \(standardDeviation(observed)) — the library bunches"
            )

            let middle = observed.filter { $0 > 33 && $0 < 67 }.count
            #expect(
                Double(middle) / Double(observed.count) < 0.55,
                "\(attribute): \(middle) of \(observed.count) tracks sit mid-scale"
            )
        }
    }

    /// A playlist may legitimately be tight on the Attribute that defines it —
    /// an acoustic playlist really is mostly acoustic. What it may never be is
    /// *constant*, which is the bug this replaces: acousticness used to be
    /// hard-coded to 0.72 for every track of a low-energy playlist, so
    /// arranging by it moved nothing at all.
    @Test("No Attribute is constant within a playlist")
    func nothingIsConstantWithinAPlaylist() {
        let catalog = DemoCatalog()

        for playlist in catalog.playlists {
            let playlistRows = rows(forPlaylist: playlist.id, in: catalog)
            for attribute in Self.scaled {
                let observed = values(playlistRows, attribute)
                #expect(
                    standardDeviation(observed) >= 9,
                    "\(playlist.name) / \(attribute): SD \(standardDeviation(observed)) — barely varies"
                )
            }
        }
    }

    /// Guards the reason the generator squashes rather than clamps. A clamp
    /// piles every out-of-range draw onto the boundary, which shows up as a
    /// block of identical numbers in an arrangement.
    @Test("No Attribute piles tracks against the ends of its range")
    func noPilingOnTheBounds() {
        let catalog = DemoCatalog()
        let all = catalog.playlists.flatMap { rows(forPlaylist: $0.id, in: catalog) }

        for attribute in Self.scaled {
            let observed = values(all, attribute)
            for (label, band) in [("bottom", 0.0...1.0), ("top", 99.0...100.0)] {
                let onBound = observed.filter { band.contains($0) }.count
                #expect(
                    Double(onBound) / Double(observed.count) < 0.03,
                    "\(attribute): \(onBound) of \(observed.count) tracks are stacked at the \(label) of the range"
                )
            }
        }
    }

    @Test("Tempo covers a musically real range rather than one narrow band")
    func tempoIsMusicallyWide() {
        let catalog = DemoCatalog()
        let all = catalog.playlists.flatMap { rows(forPlaylist: $0.id, in: catalog) }
        let tempos = values(all, .bpm)

        #expect(tempos.min()! <= 80, "nothing slow in the whole library")
        #expect(tempos.max()! >= 165, "nothing fast in the whole library")

        // Each playlist should still have its own character, or picking between
        // them means nothing.
        let centres = catalog.playlists.map { playlist -> Double in
            let observed = values(rows(forPlaylist: playlist.id, in: catalog), .bpm)
            return observed.reduce(0, +) / Double(observed.count)
        }
        #expect(centres.max()! - centres.min()! >= 40, "every playlist has the same tempo")
    }

    @Test("Loudness stays in decibels below zero and still varies")
    func loudnessIsNegativeAndVaried() {
        let catalog = DemoCatalog()
        let all = catalog.playlists.flatMap { rows(forPlaylist: $0.id, in: catalog) }
        let loudness = values(all, .loud)

        #expect(loudness.allSatisfy { $0 < 0 && $0 > -60 })
        #expect(loudness.max()! - loudness.min()! >= 12)
    }

    @Test("An acoustic playlist really is more acoustic than a loud one")
    func playlistsKeepTheirCharacter() {
        let catalog = DemoCatalog()

        func mean(_ id: String, _ attribute: Attribute) -> Double {
            let observed = values(rows(forPlaylist: id, in: catalog), attribute)
            return observed.reduce(0, +) / Double(observed.count)
        }

        #expect(mean("demo-kitchen", .acoustic) > mean("demo-longrun", .acoustic) + 20)
        #expect(mean("demo-longrun", .energy) > mean("demo-kitchen", .energy) + 20)
    }
}
