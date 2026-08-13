#if DEBUG
import Foundation
import QuartzCore

/// Measures what a reorder actually costs, so `ReorderAnimation.rowLimit` is a
/// number that was taken rather than chosen.
///
/// Runs on a **device**. Simulator frame timing is the Mac's - a reorder that
/// looks fine there says nothing about a phone, which is why the spec insists
/// this ticket opens with a measurement.
///
/// Method: sample every frame with `CADisplayLink` across a reorder and count
/// the ones that missed. A frame is *late* when the gap since the previous one
/// exceeds 1.5× what the display asked for. `CADisplayLink.duration` is read
/// per frame rather than assumed, because ProMotion changes it underneath you
/// and a hard-coded 8.33ms would report a 60Hz idle screen as catastrophic.
@MainActor
final class ReorderProfiler {
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var lateFrames = 0
    private var frames = 0
    private var worstOvershoot: Double = 0

    func start() {
        link?.invalidate()
        lastTimestamp = 0
        lateFrames = 0
        frames = 0
        worstOvershoot = 0

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        defer { lastTimestamp = link.timestamp }
        guard lastTimestamp > 0 else { return }

        frames += 1
        let expected = link.targetTimestamp - link.timestamp
        guard expected > 0 else { return }

        let actual = link.timestamp - lastTimestamp
        // 1.5× rather than 1.0×: one frame's worth of jitter is normal and
        // invisible. What a listener sees is a frame that took long enough for
        // the next one to be skipped entirely.
        if actual > expected * 1.5 {
            lateFrames += 1
            worstOvershoot = max(worstOvershoot, actual / expected)
        }
    }

    /// Frames sampled, frames that arrived late, and the worst one as a
    /// multiple of the frame budget.
    func stop() -> (frames: Int, late: Int, worst: Double) {
        link?.invalidate()
        link = nil
        return (frames, lateFrames, worstOvershoot)
    }
}

/// A playlist of invented tracks at whatever size the measurement needs.
///
/// The demo catalogue tops out at 68, and the question this ticket asks is what
/// happens at several hundred. Deliberately serves the *real* `TrackListModel`
/// and the *real* `TrackListView`, because a purpose-built list would measure
/// the harness rather than the app.
struct ProfilingMusicService: MusicService {
    let count: Int
    let canWriteBack = false

    func currentUser() async throws -> SpotifyUser { SpotifyUser(id: "profile") }
    func playlists(onBatch: @Sendable (PlaylistListing) async -> Void) async throws -> [Playlist] { [] }
    func albums(ids: [String]) async throws -> [TrackAlbum] { [] }
    func createPlaylist(userID: String, name: String, isPublic: Bool, description: String) async throws -> Playlist {
        throw DemoModeError.readOnly
    }
    func replaceTracks(playlistID: String, uris: [String]) async throws { throw DemoModeError.readOnly }

    func playlistItems(
        playlistID: String,
        ownerID: String,
        onPage: @Sendable ([PlaylistItem], Int) async -> Void
    ) async throws -> [PlaylistItem] {
        let items = (0..<count).map { index in
            PlaylistItem(
                addedAt: "2024-01-01T00:00:00Z",
                isLocal: false,
                track: Playable(
                    id: "prof-\(index)",
                    name: "Track \(index)",
                    uri: "spotify:track:prof-\(index)",
                    durationMS: 180_000,
                    artists: [TrackArtist(name: "Artist \(index % 20)")],
                    album: TrackAlbum(id: "prof-album-\(index / 3)"),
                    type: .track
                )
            )
        }
        await onPage(items, items.count)
        return items
    }
}

/// Features for every profiling track, spread so each Arrangement genuinely
/// moves rows rather than shuffling identical values.
struct ProfilingFeatureProvider: AudioFeatureProviding {
    let displayName = "Profiling"
    var unavailabilityReason: String? { get async { nil } }

    func features(forTrackIDs trackIDs: [String]) async throws -> [String: AudioFeatures] {
        var table: [String: AudioFeatures] = [:]
        for (index, id) in trackIDs.enumerated() {
            // Coprime strides, so no two Attributes agree on an order.
            table[id] = AudioFeatures(
                id: id,
                tempo: Double(60 + (index * 37) % 140),
                energy: Double((index * 17) % 100) / 100,
                danceability: Double((index * 23) % 100) / 100,
                loudness: -60 + Double((index * 29) % 60),
                valence: Double((index * 31) % 100) / 100,
                acousticness: Double((index * 13) % 100) / 100
            )
        }
        return table
    }
}
#endif
