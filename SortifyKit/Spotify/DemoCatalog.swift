import Foundation

/// The invented library Demo Mode serves.
///
/// Generated from a fixed seed, so the same playlist always produces the same
/// numbers — screenshots and tests stay reproducible across runs.
public struct DemoCatalog: Sendable {
    public static let shared = DemoCatalog()

    public let playlists: [Playlist]
    private let itemsByPlaylist: [String: [PlaylistItem]]
    private let featuresByTrack: [String: AudioFeatures]
    private let albumsByID: [String: TrackAlbum]

    public func items(forPlaylist id: String) -> [PlaylistItem] { itemsByPlaylist[id] ?? [] }
    public func features(forTrackID id: String) -> AudioFeatures? { featuresByTrack[id] }
    public func album(id: String) -> TrackAlbum? { albumsByID[id] }

    // MARK: - Generation

    private struct Spec {
        let id: String
        let name: String
        let description: String
        let owner: PlaylistOwner
        let trackCount: Int
        let isPublic: Bool
        let collaborative: Bool
        /// Centre of the tempo distribution, so each playlist sorts distinctly.
        let tempoCentre: Double
        let energyCentre: Double
        let episodes: Int
    }

    private static let specs: [Spec] = [
        Spec(id: "demo-morning", name: "Morning Ramp",
             description: "Slow start, builds all the way up.",
             owner: PlaylistOwner(id: "demo-user", displayName: "Demo Listener"),
             trackCount: 42, isPublic: false, collaborative: false,
             tempoCentre: 104, energyCentre: 0.52, episodes: 0),
        Spec(id: "demo-longrun", name: "Long Run",
             description: "Steady tempo for distance.",
             owner: PlaylistOwner(id: "demo-user", displayName: "Demo Listener"),
             trackCount: 68, isPublic: true, collaborative: false,
             tempoCentre: 162, energyCentre: 0.81, episodes: 0),
        Spec(id: "demo-kitchen", name: "Kitchen Sessions",
             description: "Acoustic, mostly unplugged.",
             owner: PlaylistOwner(id: "demo-user", displayName: "Demo Listener"),
             trackCount: 31, isPublic: false, collaborative: true,
             tempoCentre: 88, energyCentre: 0.31, episodes: 0),
        Spec(id: "demo-latenight", name: "Late Night Drive",
             description: "",
             owner: PlaylistOwner(id: "demo-user", displayName: "Demo Listener"),
             trackCount: 55, isPublic: true, collaborative: false,
             tempoCentre: 124, energyCentre: 0.66, episodes: 0),
        Spec(id: "demo-mixed", name: "Commute Mix",
             description: "Music and a couple of shows.",
             owner: PlaylistOwner(id: "demo-user", displayName: "Demo Listener"),
             trackCount: 24, isPublic: false, collaborative: false,
             tempoCentre: 112, energyCentre: 0.58, episodes: 3),
        Spec(id: "demo-shared", name: "Road Trip (shared)",
             description: "Everyone gets three picks.",
             owner: PlaylistOwner(id: "other-user", displayName: "Sam"),
             trackCount: 37, isPublic: true, collaborative: true,
             tempoCentre: 132, energyCentre: 0.74, episodes: 0),
        Spec(id: "37i9dQZF-demo-weekly", name: "Discover Weekly",
             description: "Your weekly mixtape of fresh music.",
             owner: PlaylistOwner(id: "spotify", displayName: "Spotify"),
             trackCount: 30, isPublic: false, collaborative: false,
             tempoCentre: 118, energyCentre: 0.6, episodes: 0),
    ]

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

            for index in 0..<spec.trackCount {
                let trackID = "\(spec.id)-t\(index)"
                let albumID = "\(spec.id)-a\(index / 3)"

                if albumsByID[albumID] == nil {
                    let year = 1998 + Int(generator.next(upperBound: 28))
                    let month = 1 + Int(generator.next(upperBound: 12))
                    let day = 1 + Int(generator.next(upperBound: 28))
                    albumsByID[albumID] = TrackAlbum(
                        id: albumID,
                        name: "\(Self.titleHeads[Int(generator.next(upperBound: UInt64(Self.titleHeads.count)))]) Sessions",
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
                    popularity: Int(generator.next(upperBound: 101)),
                    artists: [TrackArtist(id: "artist-\(artistIndex)", name: Self.artistNames[artistIndex])],
                    album: TrackAlbum(id: albumID, name: albumsByID[albumID]?.name),
                    type: .track
                )

                featuresByTrack[trackID] = AudioFeatures(
                    id: trackID,
                    // Spread kept narrow enough that the clamp almost never
                    // bites — otherwise a whole run of tracks piles up on the
                    // boundary value and the sorted column looks broken.
                    tempo: (spec.tempoCentre + generator.nextGaussian() * 12).clamped(to: 60...200),
                    energy: (spec.energyCentre + generator.nextGaussian() * 0.16).clamped(to: 0.02...1),
                    danceability: (0.55 + generator.nextGaussian() * 0.18).clamped(to: 0.05...0.98),
                    loudness: (-8.5 + generator.nextGaussian() * 3.4).clamped(to: -34 ... -1.2),
                    valence: (0.5 + generator.nextGaussian() * 0.24).clamped(to: 0.02...0.98),
                    acousticness: (spec.energyCentre < 0.45 ? 0.72 : 0.22 + generator.nextGaussian() * 0.18)
                        .clamped(to: 0.001...0.995),
                    instrumentalness: generator.nextDouble() * 0.6,
                    liveness: (0.14 + generator.nextGaussian() * 0.08).clamped(to: 0.02...0.9),
                    speechiness: (0.06 + generator.nextGaussian() * 0.03).clamped(to: 0.02...0.5),
                    key: Int(generator.next(upperBound: 12)),
                    mode: Int(generator.next(upperBound: 2)),
                    timeSignature: 4,
                    durationMS: durationMS
                )

                let daysAgo = Int(generator.next(upperBound: 900))
                let addedAt = ISO8601DateFormatter().string(
                    from: Date(timeIntervalSince1970: 1_735_689_600 - Double(daysAgo) * 86_400)
                )

                items.append(PlaylistItem(addedAt: addedAt, isLocal: false, track: track))
            }

            // Podcast episodes: no artists, no acoustic attributes — exactly the
            // shape that makes the sort and save paths interesting.
            for episodeIndex in 0..<spec.episodes {
                let id = "\(spec.id)-e\(episodeIndex)"
                let episode = Playable(
                    id: id,
                    name: "\(Self.showNames[episodeIndex % Self.showNames.count]) — Ep. \(12 + episodeIndex)",
                    uri: "spotify:episode:\(id)",
                    durationMS: 1_500_000 + Int(generator.next(upperBound: 2_400_000)),
                    popularity: nil,
                    artists: nil,
                    album: nil,
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
                    images: nil,
                    tracks: PlaylistTrackCount(total: items.count),
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
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
