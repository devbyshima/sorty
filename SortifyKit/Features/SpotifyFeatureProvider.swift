import Foundation

/// Spotify's own `/v1/audio-features`.
///
/// Only works for apps granted extended quota before the Nov 2024 cutoff. On the
/// first 403 it latches itself off, so a playlist load doesn't fire one doomed
/// request per 100-track page.
public actor SpotifyAudioFeatureProvider: AudioFeatureProviding {
    public nonisolated let displayName = "Spotify audio features"

    private let auth: SpotifyAuthenticator
    private let session: URLSession
    private var latchedReason: String?

    public init(auth: SpotifyAuthenticator, session: URLSession = .shared) {
        self.auth = auth
        self.session = session
    }

    public var unavailabilityReason: String? { latchedReason }

    public func features(forTrackIDs trackIDs: [String]) async throws -> [String: AudioFeatures] {
        guard latchedReason == nil, !trackIDs.isEmpty else { return [:] }

        struct Response: Decodable { let audio_features: [AudioFeatures?] }
        var result: [String: AudioFeatures] = [:]

        // The endpoint accepts at most 100 IDs.
        for batch in trackIDs.chunked(into: 100) {
            let url = URL(string: "https://api.spotify.com/v1/audio-features")!
                .appending(queryItems: [.init(name: "ids", value: batch.joined(separator: ","))])

            var request = URLRequest(url: url)
            request.setValue("Bearer \(try await auth.validAccessToken())", forHTTPHeaderField: "Authorization")

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { continue }

            if http.statusCode == 403 || http.statusCode == 404 {
                latchedReason = """
                    Spotify no longer serves audio features to this app. The endpoint was \
                    restricted in November 2024 for all apps registered after that date, and \
                    Spotify has published no replacement. Pick a different source in Settings, \
                    or sort by the columns that don't need it.
                    """
                return result
            }
            guard (200..<300).contains(http.statusCode) else { continue }

            let decoded = try JSONDecoder().decode(Response.self, from: data)
            for feature in decoded.audio_features.compactMap(\.self) {
                result[feature.id] = feature
            }
        }
        return result
    }
}
