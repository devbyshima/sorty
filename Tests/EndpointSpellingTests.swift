import Foundation
import Testing

/// Which spelling of the playlist-contents endpoint the service uses, and what
/// it concludes when one of them fails.
///
/// February 2026 renamed `/playlists/{id}/tracks` to `/playlists/{id}/items`,
/// and March 2026 removed the old spelling for Development Mode apps, which is
/// every Sortify listener. So the service tries `/items` and keeps `/tracks` as
/// a fallback for a Client ID old enough to predate it. The latch that
/// remembers the answer is what these are about: it used to be set on the way
/// *into* the fallback rather than on the fallback working, so a single 404
/// from a playlist that was never readable pointed the rest of the session at
/// a removed endpoint, and the whole library stopped loading.
@Suite("Endpoint spelling", .serialized)
struct EndpointSpellingTests {

    private func service(_ route: @escaping @Sendable (URLRequest) -> StubResponse) -> SpotifyMusicService {
        StubURLProtocol.route = route
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let store = FixedTokenStore()
        let auth = SpotifyAuthenticator(
            config: SpotifyAuthConfig(clientID: "cid", redirectURI: "sortify://callback"),
            store: store,
            session: session
        )
        return SpotifyMusicService(auth: auth, session: session)
    }

    private func page(_ count: Int) -> StubResponse {
        let items = (0..<count).map {
            #"{"added_at":"2024-01-01T00:00:00Z","item":{"id":"t\#($0)","name":"Track \#($0)","type":"track"}}"#
        }
        return StubResponse(status: 200, body: #"{"items":[\#(items.joined(separator: ","))],"next":null,"total":\#(count)}"#)
    }

    private func load(_ service: SpotifyMusicService, _ id: String) async -> Result<[PlaylistItem], any Error> {
        do {
            return .success(try await service.playlistItems(playlistID: id, ownerID: "sam") { _, _ in })
        } catch {
            return .failure(error)
        }
    }

    /// The regression. A playlist Spotify will not show anyone answers 404 to
    /// `/items`, which is the same status a Client ID that predates `/items`
    /// answers with, so the fallback is tried - and when it fails too, the
    /// spelling was never the problem and the session must not be left believing
    /// otherwise.
    @Test("One unreadable playlist doesn't send the rest of the session to a removed endpoint")
    func aFailedFallbackDoesNotLatch() async {
        let service = service { request in
            let path = request.url?.path ?? ""
            if path.contains("/gone/") { return StubResponse(status: 404, body: #"{"error":{"status":404}}"#) }
            // The state of a Development Mode app since March 2026: the old
            // spelling is not merely absent, it is refused.
            if path.hasSuffix("/tracks") { return StubResponse(status: 403, body: #"{"error":{"status":403}}"#) }
            return self.page(3)
        }

        let refused = await load(service, "gone")
        #expect(refused.isFailure, "a playlist Spotify won't show stays refused")

        let mine = await load(service, "mine")
        #expect(try! mine.get().count == 3, "the next playlist still loads")
    }

    /// The fallback still exists for the Client ID it was written for, and once
    /// the older spelling answers, the session stays on it.
    @Test("A Client ID that predates /items falls back and stays there")
    func aWorkingFallbackLatches() async {
        let requested = Recorder()
        let service = service { request in
            let path = request.url?.path ?? ""
            Task { await requested.append(path) }
            if path.hasSuffix("/items") { return StubResponse(status: 404, body: #"{"error":{"status":404}}"#) }
            return self.page(2)
        }

        let first = await load(service, "p1")
        #expect(try! first.get().count == 2)

        let second = await load(service, "p2")
        #expect(try! second.get().count == 2)

        let paths = await requested.paths
        #expect(paths.filter { $0.hasSuffix("/items") }.count == 1, "the dead spelling is tried once, not once per playlist")
    }

    /// A 403 is Spotify refusing this playlist, not this path. Trying the other
    /// spelling would spend a request to be refused identically, and would put
    /// the session on an endpoint that no longer exists for it.
    @Test("A refusal is not treated as a misspelled endpoint")
    func forbiddenIsNotAFallbackTrigger() async {
        let requested = Recorder()
        let service = service { request in
            Task { await requested.append(request.url?.path ?? "") }
            return StubResponse(status: 403, body: #"{"error":{"status":403,"message":"Forbidden"}}"#)
        }

        let result = await load(service, "theirs")
        #expect(result.isFailure)

        let paths = await requested.paths
        #expect(paths.count == 1, "one refusal, one request")
        #expect(paths.allSatisfy { $0.hasSuffix("/items") })
    }
}

// MARK: - Doubles

private struct StubResponse: Sendable {
    let status: Int
    let body: String
}

/// Locked rather than an actor: the route closure that records is synchronous
/// and runs on URLSession's thread, so hopping to an actor would leave the
/// appends still queued when the assertion reads them.
private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    func append(_ path: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(path)
    }

    var paths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

/// A token that is already valid, so the service under test never takes the
/// refresh path.
private struct FixedTokenStore: TokenStoring {
    func load() -> SpotifyTokens? {
        SpotifyTokens(
            accessToken: "token",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600),
            grantedScopes: SpotifyAuthConfig.requiredScopes
        )
    }
    func save(_ tokens: SpotifyTokens) {}
    func clear() {}
}

/// Answers requests from a closure instead of the network. The suite is
/// `.serialized` because this route is process-wide.
private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var route: (@Sendable (URLRequest) -> StubResponse)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let answer = Self.route?(request) ?? StubResponse(status: 500, body: "{}")
        let response = HTTPURLResponse(
            url: request.url!, statusCode: answer.status, httpVersion: "HTTP/1.1", headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(answer.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension Result {
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}
