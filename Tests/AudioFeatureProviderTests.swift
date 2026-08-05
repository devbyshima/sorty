import Foundation
import Testing

@Suite("ReccoBeats mapping")
struct ReccoBeatsMappingTests {

    /// ReccoBeats keys its own rows by an internal UUID and only names the
    /// Spotify track in `href`. Keying the feature table by `id` would silently
    /// map every track to nothing, so this mapping is the load-bearing bit.
    @Test("The Spotify ID is taken from href, never from the ReccoBeats id")
    func extractsSpotifyIDFromHref() {
        #expect(
            ReccoBeatsAudioFeatureProvider.spotifyTrackID(
                fromHref: "https://open.spotify.com/track/3n3Ppam7vgaVa1iaRUc9Lp"
            ) == "3n3Ppam7vgaVa1iaRUc9Lp"
        )
    }

    @Test("A market-scoped or query-suffixed href still resolves")
    func handlesQueryAndLocale() {
        #expect(
            ReccoBeatsAudioFeatureProvider.spotifyTrackID(
                fromHref: "https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b?si=abc123"
            ) == "0VjIjW4GlUZAMYd2vXMi3b"
        )
        #expect(
            ReccoBeatsAudioFeatureProvider.spotifyTrackID(
                fromHref: "https://open.spotify.com/intl-de/track/0VjIjW4GlUZAMYd2vXMi3b"
            ) == "0VjIjW4GlUZAMYd2vXMi3b"
        )
    }

    @Test("Anything that isn't a track href yields nil rather than a wrong key")
    func rejectsNonTrackHrefs() {
        #expect(ReccoBeatsAudioFeatureProvider.spotifyTrackID(fromHref: nil) == nil)
        #expect(ReccoBeatsAudioFeatureProvider.spotifyTrackID(fromHref: "") == nil)
        #expect(ReccoBeatsAudioFeatureProvider.spotifyTrackID(fromHref: "https://open.spotify.com/album/xyz") == nil)
        #expect(ReccoBeatsAudioFeatureProvider.spotifyTrackID(fromHref: "https://open.spotify.com/track/") == nil)
    }
}

@Suite("Feature provider fallbacks")
struct FeatureProviderFallbackTests {

    @Test("The no-source provider returns nothing and explains itself")
    func noProviderExplains() async throws {
        let provider = NoAudioFeatureProvider()
        #expect(try await provider.features(forTrackIDs: ["a", "b"]).isEmpty)
        let reason = await provider.unavailabilityReason
        #expect(reason != nil)
    }

    @Test("Empty input never hits the network")
    func emptyInputShortCircuits() async throws {
        let provider = ReccoBeatsAudioFeatureProvider(session: .offline)
        #expect(try await provider.features(forTrackIDs: []).isEmpty)
        // Nothing was requested, so there is nothing to explain.
        #expect(await provider.unavailabilityReason == nil)
    }

    @Test("A total miss is reported as a coverage gap, not silence")
    func totalMissIsExplained() async throws {
        let provider = ReccoBeatsAudioFeatureProvider(session: .offline)
        let result = try await provider.features(forTrackIDs: ["a", "b", "c"])
        #expect(result.isEmpty)

        let reason = await provider.unavailabilityReason
        #expect(reason?.contains("no acoustic data") == true)
    }

    /// Not every track: the demo catalogue deliberately leaves some without
    /// features, the way a real provider misses recent releases. The provider's
    /// job is to answer for the ones it has and stay quiet about the rest —
    /// never to invent a value, and never to report the whole playlist
    /// unavailable because part of it is.
    @Test("Demo features cover most of the catalogue, and omit the rest silently")
    func demoProviderCoversCatalog() async throws {
        let catalog = DemoCatalog()
        let provider = DemoAudioFeatureProvider(catalog: catalog)
        let ids = catalog.items(forPlaylist: "demo-morning").compactMap { $0.track?.id }

        let features = try await provider.features(forTrackIDs: ids)
        #expect(features.count < ids.count, "some tracks must be missing features")
        #expect(Double(features.count) / Double(ids.count) > 0.8, "but most must have them")
        #expect(features.keys.allSatisfy { ids.contains($0) })
        #expect(await provider.unavailabilityReason == nil)
    }

    @Test("Musical key renders only when the provider detected one")
    func keyDescription() {
        #expect(AudioFeatures(id: "x", key: 6, mode: 0).keyDescription == "F♯ min")
        #expect(AudioFeatures(id: "x", key: 0, mode: 1).keyDescription == "C maj")
        #expect(AudioFeatures(id: "x", key: -1, mode: 1).keyDescription == nil)
        #expect(AudioFeatures(id: "x").keyDescription == nil)
    }
}

private extension URLSession {
    /// A session that cannot reach the network, so provider fallbacks are
    /// exercised without depending on a live third-party service in CI.
    static var offline: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailingProtocol.self]
        configuration.timeoutIntervalForRequest = 1
        return URLSession(configuration: configuration)
    }
}

private final class FailingProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }
    override func stopLoading() {}
}
