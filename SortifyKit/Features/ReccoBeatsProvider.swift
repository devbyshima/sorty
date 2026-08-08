import Foundation

/// Audio features from ReccoBeats (api.reccobeats.com).
///
/// This is what makes the BPM / Energy / Dance / Loud / Valence / Acoustic
/// columns work at all on a Spotify app registered after November 2024, when
/// Spotify closed its own `/v1/audio-features` endpoint. ReccoBeats is keyed by
/// Spotify track ID, needs no API key, and returns values on Spotify's exact
/// scale, so nothing downstream has to change.
///
/// Known limits, surfaced to the user rather than hidden:
///   * it mirrors a snapshot of the pre-deprecation dataset, so coverage is
///     excellent for older catalogue and thin for 2025-onward releases;
///   * a lookup that misses returns HTTP 200 with the track simply absent, so
///     misses are detected by diffing requested against returned IDs;
///   * batches are capped at 40 IDs.
public actor ReccoBeatsAudioFeatureProvider: AudioFeatureProviding {
    public nonisolated let displayName = "ReccoBeats"

    private let session: URLSession
    private let endpoint = URL(string: "https://api.reccobeats.com/v1/audio-features")!
    /// The API rejects anything larger.
    private let batchLimit = 40
    private let maxRetries = 2

    private var lastRequested = 0
    private var lastReturned = 0

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public var unavailabilityReason: String? {
        guard lastRequested > 0 else { return nil }
        guard lastReturned < lastRequested else { return nil }

        if lastReturned == 0 {
            return """
                ReccoBeats had no acoustic data for any track in this playlist. Its catalogue \
                mirrors Spotify's pre-2025 dataset, so very recent releases are often missing.
                """
        }
        let missing = lastRequested - lastReturned
        return """
            ReccoBeats had no acoustic data for \(missing) of \(lastRequested) tracks. They \
            have no BPM, Energy, Danceability, Loudness, Valence or Acousticness, so those \
            arrangements can't rank them. Coverage is thinnest on releases from 2025 onward.
            """
    }

    public func features(forTrackIDs trackIDs: [String]) async throws -> [String: AudioFeatures] {
        guard !trackIDs.isEmpty else { return [:] }

        lastRequested = trackIDs.count
        var result: [String: AudioFeatures] = [:]

        for batch in trackIDs.chunked(into: batchLimit) {
            let features = await fetchBatch(batch)
            result.merge(features) { current, _ in current }
        }

        lastReturned = result.count
        return result
    }

    // MARK: - Wire format

    /// ReccoBeats assigns its own UUID in `id` and identifies the Spotify track
    /// only through `href`, so the Spotify ID has to be parsed back out of that
    /// URL - using `id` directly would key the whole table by the wrong string.
    private struct Entry: Decodable {
        let href: String?
        let tempo: Double?
        let energy: Double?
        let danceability: Double?
        let loudness: Double?
        let valence: Double?
        let acousticness: Double?
        let instrumentalness: Double?
        let liveness: Double?
        let speechiness: Double?
        let key: Int?
        let mode: Int?

        var spotifyTrackID: String? {
            ReccoBeatsAudioFeatureProvider.spotifyTrackID(fromHref: href)
        }
    }

    /// Pulls the Spotify track ID out of a ReccoBeats `href`
    /// (`https://open.spotify.com/track/<id>`). Exposed so the mapping that the
    /// whole feature table is keyed by can be tested against real payloads.
    static func spotifyTrackID(fromHref href: String?) -> String? {
        guard let href, let url = URL(string: href) else { return nil }
        let components = url.pathComponents
        guard let trackIndex = components.firstIndex(of: "track"),
              case let idIndex = components.index(after: trackIndex),
              idIndex < components.endIndex
        else { return nil }
        let id = components[idIndex]
        return id.isEmpty ? nil : id
    }

    private struct Envelope: Decodable {
        let content: [Entry]?
    }

    private func fetchBatch(_ ids: [String], attempt: Int = 0) async -> [String: AudioFeatures] {
        let url = endpoint.appending(queryItems: [.init(name: "ids", value: ids.joined(separator: ","))])
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return [:] }

            if http.statusCode == 429, attempt < maxRetries {
                let retryAfter = TimeInterval(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 2
                try await Task.sleep(for: .seconds(min(retryAfter, 15)))
                return await fetchBatch(ids, attempt: attempt + 1)
            }
            guard (200..<300).contains(http.statusCode) else { return [:] }

            let decoder = JSONDecoder()
            // The bulk endpoint wraps results in `content`; single lookups and
            // some deployments return a bare array.
            let entries: [Entry]
            if let envelope = try? decoder.decode(Envelope.self, from: data), let content = envelope.content {
                entries = content
            } else if let bare = try? decoder.decode([Entry].self, from: data) {
                entries = bare
            } else {
                return [:]
            }

            var mapped: [String: AudioFeatures] = [:]
            for entry in entries {
                guard let id = entry.spotifyTrackID else { continue }
                mapped[id] = AudioFeatures(
                    id: id,
                    tempo: entry.tempo,
                    energy: entry.energy,
                    danceability: entry.danceability,
                    loudness: entry.loudness,
                    valence: entry.valence,
                    acousticness: entry.acousticness,
                    instrumentalness: entry.instrumentalness,
                    liveness: entry.liveness,
                    speechiness: entry.speechiness,
                    key: entry.key,
                    mode: entry.mode,
                    // ReccoBeats returns neither; the track's own duration covers
                    // the Length column.
                    timeSignature: nil,
                    durationMS: nil
                )
            }
            return mapped
        } catch {
            return [:]
        }
    }
}
