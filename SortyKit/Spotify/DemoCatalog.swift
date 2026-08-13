import Foundation

#if DEBUG
// Test and screenshot-harness scaffolding only. ADR-0007 removed Demo Mode from
// the shipped app; this whole file compiles out of Release.

/// The invented library Demo Mode serves.
///
/// Generated from a fixed seed, so the same playlist always produces the same
/// numbers - screenshots and tests stay reproducible across runs.
public struct DemoCatalog: Sendable {
    public static let shared = DemoCatalog()

    /// Who the catalogue belongs to. Named once because it decides a rule now
    /// rather than only labelling rows: a playlist owned by anyone else is one
    /// Spotify would refuse to open, and the fixtures have to reflect that.
    public static let userID = "demo-user"

    public let playlists: [Playlist]
    private let itemsByPlaylist: [String: [PlaylistItem]]
    private let featuresByTrack: [String: AudioFeatures]
    private let albumsByID: [String: TrackAlbum]

    public func items(forPlaylist id: String) -> [PlaylistItem] { itemsByPlaylist[id] ?? [] }
    public func features(forTrackID id: String) -> AudioFeatures? { featuresByTrack[id] }
    public func album(id: String) -> TrackAlbum? { albumsByID[id] }

    // MARK: - Generation

    /// Each playlist has its own musical character - that is what makes picking
    /// between them mean something, and what makes an arrangement of one look
    /// different from an arrangement of another. Centres set the character;
    /// the spread around them is wide enough that any single playlist still
    /// covers most of each Attribute's range.
    private struct Spec {
        let id: String
        let name: String
        let description: String
        let owner: PlaylistOwner
        let trackCount: Int
        let isPublic: Bool
        let collaborative: Bool
        let tempoCentre: Double
        let energyCentre: Double
        let danceCentre: Double
        let valenceCentre: Double
        let acousticCentre: Double
        let episodes: Int
        /// Tracks the audio-feature provider has nothing for. Real playlists
        /// have these - ReccoBeats' catalogue is patchy for recent releases -
        /// and the unrankable group in ticket 05 needs them to exist.
        let tracksWithoutFeatures: Int
    }

    private static let specs: [Spec] = [
        Spec(id: "demo-morning", name: "Morning Ramp",
             description: "Slow start, builds all the way up.",
             owner: PlaylistOwner(id: "demo-user", displayName: "Demo Listener"),
             trackCount: 42, isPublic: false, collaborative: false,
             tempoCentre: 104, energyCentre: 0.52, danceCentre: 0.58,
             valenceCentre: 0.62, acousticCentre: 0.38,
             episodes: 0, tracksWithoutFeatures: 3),
        Spec(id: "demo-longrun", name: "Long Run",
             description: "Steady tempo for distance.",
             owner: PlaylistOwner(id: "demo-user", displayName: "Demo Listener"),
             trackCount: 68, isPublic: true, collaborative: false,
             tempoCentre: 164, energyCentre: 0.82, danceCentre: 0.66,
             valenceCentre: 0.58, acousticCentre: 0.12,
             episodes: 0, tracksWithoutFeatures: 5),
        Spec(id: "demo-kitchen", name: "Kitchen Sessions",
             description: "Acoustic, mostly unplugged.",
             owner: PlaylistOwner(id: "demo-user", displayName: "Demo Listener"),
             trackCount: 31, isPublic: false, collaborative: true,
             tempoCentre: 86, energyCentre: 0.28, danceCentre: 0.36,
             valenceCentre: 0.44, acousticCentre: 0.82,
             episodes: 0, tracksWithoutFeatures: 2),
        Spec(id: "demo-latenight", name: "Late Night Drive",
             description: "",
             owner: PlaylistOwner(id: "demo-user", displayName: "Demo Listener"),
             trackCount: 55, isPublic: true, collaborative: false,
             tempoCentre: 124, energyCentre: 0.66, danceCentre: 0.62,
             valenceCentre: 0.34, acousticCentre: 0.24,
             episodes: 0, tracksWithoutFeatures: 4),
        Spec(id: "demo-mixed", name: "Commute Mix",
             description: "Music and a couple of shows.",
             owner: PlaylistOwner(id: "demo-user", displayName: "Demo Listener"),
             trackCount: 24, isPublic: false, collaborative: false,
             tempoCentre: 112, energyCentre: 0.58, danceCentre: 0.54,
             valenceCentre: 0.5, acousticCentre: 0.34,
             episodes: 3, tracksWithoutFeatures: 2),
        Spec(id: "demo-shared", name: "Road Trip (shared)",
             description: "Everyone gets three picks.",
             owner: PlaylistOwner(id: "other-user", displayName: "Sam"),
             trackCount: 37, isPublic: true, collaborative: true,
             tempoCentre: 132, energyCentre: 0.74, danceCentre: 0.7,
             valenceCentre: 0.72, acousticCentre: 0.2,
             episodes: 0, tracksWithoutFeatures: 3),
        // Another listener's playlist, and not a shared one: the case Spotify
        // will name but never open (ADR-0008). It arrives the way a real one
        // does, with no track count, which is what the harness needs in order to
        // photograph a row that says so and the screen behind it.
        Spec(id: "demo-borrowed", name: "Sam's Coffee House",
             description: "Sam's, and Sam's alone.",
             owner: PlaylistOwner(id: "other-user", displayName: "Sam"),
             trackCount: 29, isPublic: true, collaborative: false,
             tempoCentre: 94, energyCentre: 0.36, danceCentre: 0.44,
             valenceCentre: 0.56, acousticCentre: 0.7,
             episodes: 0, tracksWithoutFeatures: 2),
        // The stem a real Discover Weekly carries. It is **not** `37i9dQZF…`,
        // which is what this fixture said for a year and what `isPersonalized`
        // checked - so the two agreed with each other and with nothing on
        // Spotify, and the predicate named after this playlist never once
        // matched it. ADR-0018.
        Spec(id: "37i9dQZEVXcDEMOWEEKLY1", name: "Discover Weekly",
             description: "Your weekly mixtape of fresh music.",
             owner: PlaylistOwner(id: "spotify", displayName: "Spotify"),
             trackCount: 30, isPublic: false, collaborative: false,
             tempoCentre: 118, energyCentre: 0.6, danceCentre: 0.56,
             valenceCentre: 0.52, acousticCentre: 0.42,
             episodes: 0, tracksWithoutFeatures: 6),
        // Spotify publishes the charts under an account of their own, and a
        // playlist of theirs used to land in `.other` and be told to ask its
        // owner for a collaborator's invite. Nobody is going to ask Spotify for
        // one. Here so the fixed routing has something to be right about.
        Spec(id: "37i9dQZEVXbDEMOCHARTS1", name: "Top 50 - Global",
             description: "Your daily update of the most played tracks.",
             owner: PlaylistOwner(id: "spotifycharts", displayName: "spotifycharts"),
             trackCount: 50, isPublic: true, collaborative: false,
             tempoCentre: 120, energyCentre: 0.7, danceCentre: 0.72,
             valenceCentre: 0.6, acousticCentre: 0.18,
             episodes: 0, tracksWithoutFeatures: 8),
    ]

    /// Entries Spotify listed and would not describe.
    ///
    /// The catalogue is an array of playlists and cannot hold a hole, so the
    /// number is stated rather than derived - which is the only way the footer
    /// that reports it can be photographed at all. Three, because one would not
    /// exercise the plural and a dozen would read as a broken account.
    public static let withheldFromListing = 3

    private static let artistNames = [
        "Halcyon Field", "Vera Ash", "The Longwater", "Nils Bergström", "Kite & Anchor",
        "Marisol Reyes", "Paper Cinema", "Odd Even", "The Slow Hours", "Juniper Vale",
        "Cassius Grey", "Northbound", "Ilse Vandermeer", "Tin Orchard", "Ruby Sixteen",
        "Elian Moss", "The Quiet Fleet", "Sable & Sons", "Wren Okonkwo", "Fathom Line",
    ]

    private static let titleHeads = [
        "Blue", "Paper", "Static", "Golden", "Hollow", "Neon", "Salt", "Winter",
        "Radio", "Velvet", "Iron", "Quiet", "Amber", "Glass", "Wild", "Slow",
    ]

    private static let titleTails = [
        "Hours", "Lantern", "Harbour", "Weather", "Machine", "Avenue", "Sirens", "Letters",
        "Orbit", "Mornings", "Corridor", "Distances", "Signal", "Garden", "Traffic", "Echoes",
    ]

    private static let showNames = ["The Long Version", "Field Notes", "Two Thousand Words"]

    public init() {
        var generator = SplitMix64(seed: 0x5079_0000_5346_1234)

        var playlists: [Playlist] = []
        var itemsByPlaylist: [String: [PlaylistItem]] = [:]
        var featuresByTrack: [String: AudioFeatures] = [:]
        var albumsByID: [String: TrackAlbum] = [:]

        for spec in Self.specs {
            var items: [PlaylistItem] = []

            // Which tracks the feature provider will have nothing for. Chosen
            // up front so they are scattered through the playlist rather than
            // bunched at the end, which is what a real provider miss looks like.
            var featurelessIndices: Set<Int> = []
            while featurelessIndices.count < min(spec.tracksWithoutFeatures, spec.trackCount) {
                featurelessIndices.insert(Int(generator.next(upperBound: UInt64(spec.trackCount))))
            }

            for index in 0..<spec.trackCount {
                let trackID = "\(spec.id)-t\(index)"
                let albumID = "\(spec.id)-a\(index / 3)"

                let albumArtwork = DemoArtwork.images(seed: albumID)

                if albumsByID[albumID] == nil {
                    let year = 1998 + Int(generator.next(upperBound: 28))
                    let month = 1 + Int(generator.next(upperBound: 12))
                    let day = 1 + Int(generator.next(upperBound: 28))
                    albumsByID[albumID] = TrackAlbum(
                        id: albumID,
                        name: "\(Self.titleHeads[Int(generator.next(upperBound: UInt64(Self.titleHeads.count)))]) Sessions",
                        images: albumArtwork,
                        releaseDate: String(format: "%04d-%02d-%02d", year, month, day)
                    )
                }

                // A couple of artists dominate each playlist, so the artist
                // separation column has something real to spread out.
                let artistIndex: Int
                let roll = generator.nextDouble()
                if roll < 0.34 {
                    artistIndex = Int(generator.next(upperBound: 3))
                } else {
                    artistIndex = Int(generator.next(upperBound: UInt64(Self.artistNames.count)))
                }

                let title = "\(Self.titleHeads[Int(generator.next(upperBound: UInt64(Self.titleHeads.count)))]) "
                    + Self.titleTails[Int(generator.next(upperBound: UInt64(Self.titleTails.count)))]

                let durationMS = 128_000 + Int(generator.next(upperBound: 210_000))

                let track = Playable(
                    id: trackID,
                    name: title,
                    uri: "spotify:track:\(trackID)",
                    durationMS: durationMS,
                    artists: [TrackArtist(id: "artist-\(artistIndex)", name: Self.artistNames[artistIndex])],
                    // The whole album, release date included: Spotify's simplified
                    // album carries `release_date`, and a fixture that left it out
                    // is what let the release-date bug pass every demo test.
                    album: albumsByID[albumID],
                    type: .track
                )

                // Every draw is bounded rather than clamped, so the spread can
                // be wide enough to fill each Attribute's range without a run of
                // tracks piling onto a boundary value.
                let energy = generator.nextBounded(
                    centre: spec.energyCentre, spread: 0.9, in: 0.02...0.99
                )

                if !featurelessIndices.contains(index) {
                    featuresByTrack[trackID] = AudioFeatures(
                        id: trackID,
                        tempo: generator.nextBounded(centre: spec.tempoCentre, spread: 0.85, in: 60...200),
                        energy: energy,
                        danceability: generator.nextBounded(
                            centre: spec.danceCentre, spread: 0.95, in: 0.02...0.99
                        ),
                        // Louder tracks really are more energetic, so loudness
                        // tracks energy rather than wandering independently.
                        loudness: generator.nextBounded(
                            centre: -26 + energy * 22, spread: 0.7, in: -38 ... -1.5
                        ),
                        valence: generator.nextBounded(
                            centre: spec.valenceCentre, spread: 0.95, in: 0.02...0.99
                        ),
                        acousticness: generator.nextBounded(
                            centre: spec.acousticCentre, spread: 0.9, in: 0.005...0.995
                        ),
                        instrumentalness: generator.nextDouble() * 0.6,
                        liveness: generator.nextBounded(centre: 0.14, spread: 0.7, in: 0.02...0.9),
                        speechiness: generator.nextBounded(centre: 0.07, spread: 0.6, in: 0.02...0.5),
                        key: Int(generator.next(upperBound: 12)),
                        mode: Int(generator.next(upperBound: 2)),
                        timeSignature: 4,
                        durationMS: durationMS
                    )
                }

                let daysAgo = Int(generator.next(upperBound: 900))
                let addedAt = ISO8601DateFormatter().string(
                    from: Date(timeIntervalSince1970: 1_735_689_600 - Double(daysAgo) * 86_400)
                )

                items.append(PlaylistItem(addedAt: addedAt, isLocal: false, track: track))
            }

            // Podcast episodes: no artists, no acoustic attributes - exactly the
            // shape that makes the sort and save paths interesting.
            for episodeIndex in 0..<spec.episodes {
                let id = "\(spec.id)-e\(episodeIndex)"
                let episode = Playable(
                    id: id,
                    name: "\(Self.showNames[episodeIndex % Self.showNames.count]): Ep. \(12 + episodeIndex)",
                    uri: "spotify:episode:\(id)",
                    durationMS: 1_500_000 + Int(generator.next(upperBound: 2_400_000)),
                    artists: nil,
                    album: nil,
                    // An episode belongs to a show, not an album, so it carries
                    // its own artwork - seeded by the show so a series looks
                    // like a series.
                    images: DemoArtwork.images(seed: "show-\(Self.showNames[episodeIndex % Self.showNames.count])"),
                    type: .episode
                )
                let position = Int(generator.next(upperBound: UInt64(max(1, items.count))))
                items.insert(PlaylistItem(addedAt: nil, isLocal: false, track: episode), at: position)
            }

            itemsByPlaylist[spec.id] = items
            playlists.append(
                Playlist(
                    id: spec.id,
                    name: spec.name,
                    uri: "spotify:playlist:\(spec.id)",
                    owner: spec.owner,
                    images: DemoArtwork.images(seed: spec.id),
                    tracks: PlaylistTrackCount(total: items.count),
                    // Spotify sends a count only for playlists the listener owns
                    // or collaborates on, so the ones it withholds arrive here
                    // without one too. A fixture that reported a count for every
                    // playlist would make the row that has to cope with a
                    // missing one unreachable.
                    trackCountIsKnown: spec.owner.id == Self.userID || spec.collaborative,
                    collaborative: spec.collaborative,
                    isPublic: spec.isPublic,
                    rawDescription: spec.description.isEmpty ? nil : spec.description
                )
            )
        }

        self.playlists = playlists
        self.itemsByPlaylist = itemsByPlaylist
        self.featuresByTrack = featuresByTrack
        self.albumsByID = albumsByID
    }
}

// MARK: - Deterministic randomness

/// Seeded PRNG so the demo catalogue is byte-identical on every launch.
/// `SystemRandomNumberGenerator` would reshuffle the data each run and make
/// screenshots and tests non-reproducible.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(upperBound: UInt64) -> UInt64 {
        upperBound == 0 ? 0 : next() % upperBound
    }

    mutating func nextDouble() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    /// Box–Muller, so feature values cluster around each playlist's centre
    /// instead of spreading uniformly.
    mutating func nextGaussian() -> Double {
        let u1 = max(nextDouble(), .leastNormalMagnitude)
        let u2 = nextDouble()
        return (-2 * Foundation.log(u1)).squareRoot() * Foundation.cos(2 * .pi * u2)
    }

    /// A value in `range`, clustered around `centre`, spread by `spread`.
    ///
    /// The draw is squashed through a logistic curve rather than clamped.
    /// Clamping is what made the old catalogue look wrong: a wide spread piled a
    /// run of tracks onto the boundary value, so an arrangement showed a block
    /// of identical numbers and the position bars in ticket 04 would all be full
    /// or all empty. A logistic approaches the bounds without ever reaching
    /// them, so the spread can be as wide as the music warrants.
    mutating func nextBounded(
        centre: Double, spread: Double, in range: ClosedRange<Double>
    ) -> Double {
        let width = range.upperBound - range.lowerBound
        let fraction = ((centre - range.lowerBound) / width).clamped(to: 0.02...0.98)
        let logit = Foundation.log(fraction / (1 - fraction))
        let drawn = logit + nextGaussian() * spread
        return range.lowerBound + width / (1 + Foundation.exp(-drawn))
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
#endif
