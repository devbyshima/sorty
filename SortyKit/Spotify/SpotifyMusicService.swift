import Foundation

/// Talks to the Spotify Web API.
public actor SpotifyMusicService: MusicService {
    private let auth: SpotifyAuthenticator
    private let session: URLSession
    private let base = URL(string: "https://api.spotify.com/v1")!

    /// How many times to wait out a 429 before giving up.
    private let maxRateLimitRetries = 3

    /// Latched once the newer `/items` endpoints 404, so older Client IDs don't
    /// pay a failed request per page for the rest of the session.
    private var usedLegacyItemsPath = false

    /// Latched once the older spelling has been tried and refused.
    ///
    /// The probe exists for a Client ID old enough to predate `/items`. For
    /// every other one - which since March 2026 is every Development Mode app,
    /// so very nearly all of them - `/tracks` is not merely absent, it is
    /// refused, and probing can only turn a clean 404 into a misleading 403 at
    /// the cost of a request from a five-listener quota.
    ///
    /// ADR-0008 un-latched a failed probe so that one unreadable playlist could
    /// not poison the session, which was right and is kept. What it also threw
    /// away was what the probe had just *proved*, so a library holding twelve
    /// playlists Spotify won't open spent twelve requests proving the same thing
    /// twelve times. The question the probe answers is about the Client ID, not
    /// about the playlist, so it is worth asking once and never again.
    private var legacyPathIsRuledOut = false

    public init(auth: SpotifyAuthenticator, session: URLSession = .shared) {
        self.auth = auth
        self.session = session
    }

    // MARK: - Request plumbing

    private struct SpotifyErrorEnvelope: Decodable {
        struct Inner: Decodable {
            let status: Int?
            let message: String?
            /// Development-mode quota exhaustion sets this to "QUOTA_EXCEEDED".
            let reason: String?
        }
        let error: Inner?
    }

    /// One authenticated request. Refreshes once on 401, waits out 429s, and
    /// surfaces everything else as a typed error.
    private func send<T: Decodable>(
        _ request: URLRequest,
        decode: T.Type,
        attempt: Int = 0,
        didRefresh: Bool = false
    ) async throws -> T? {
        var request = request
        let token: String
        do {
            token = try await auth.validAccessToken()
        } catch {
            throw SpotifyAPIError.notAuthenticated
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SpotifyAPIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SpotifyAPIError.http(status: -1, message: nil)
        }

        switch http.statusCode {
        case 401 where !didRefresh:
            _ = try? await auth.refresh()
            return try await send(request, decode: T.self, attempt: attempt, didRefresh: true)

        case 401:
            throw SpotifyAPIError.notAuthenticated

        case 429:
            // Two different 429s share this status. A rolling-window rate limit
            // clears on its own, so wait it out. Development-mode quota
            // exhaustion does not - retrying just burns the remaining budget.
            let envelope = try? JSONDecoder().decode(SpotifyErrorEnvelope.self, from: data)
            if envelope?.error?.reason == "QUOTA_EXCEEDED" {
                throw SpotifyAPIError.quotaExceeded
            }
            let retryAfter = TimeInterval(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 2
            guard attempt < maxRateLimitRetries else {
                throw SpotifyAPIError.rateLimited(retryAfter: retryAfter)
            }
            try await Task.sleep(for: .seconds(min(retryAfter, 30)))
            return try await send(request, decode: T.self, attempt: attempt + 1, didRefresh: didRefresh)

        case 200..<300:
            // 201/202/204 bodies are empty or irrelevant for the write paths.
            if data.isEmpty || http.statusCode == 204 { return nil }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                // A write that returns an unexpected shape still succeeded.
                if T.self == EmptyResponse.self { return nil }
                throw SpotifyAPIError.decoding(error)
            }

        default:
            let message = (try? JSONDecoder().decode(SpotifyErrorEnvelope.self, from: data))?.error?.message
            throw SpotifyAPIError.http(status: http.statusCode, message: message)
        }
    }

    struct EmptyResponse: Decodable {}

    private func get<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T? {
        try await send(URLRequest(url: url), decode: type)
    }

    private func write<Body: Encodable>(
        _ method: String,
        _ url: URL,
        body: Body
    ) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        _ = try await send(request, decode: EmptyResponse.self)
    }

    private func writeReturning<Body: Encodable, T: Decodable>(
        _ method: String,
        _ url: URL,
        body: Body,
        as type: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        guard let result = try await send(request, decode: type) else {
            throw SpotifyAPIError.http(status: -1, message: "Spotify returned an empty response.")
        }
        return result
    }

    // MARK: - MusicService

    public func currentUser() async throws -> SpotifyUser {
        guard let user = try await get(base.appending(path: "me"), as: SpotifyUser.self) else {
            throw SpotifyAPIError.notAuthenticated
        }
        return user
    }

    public func playlists(onBatch: @Sendable (PlaylistListing) async -> Void) async throws -> [Playlist] {
        var next: URL? = base.appending(path: "me/playlists")
            .appending(queryItems: [.init(name: "limit", value: "50")])
        var listing = PlaylistListing()

        while let url = next {
            try Task.checkCancellation()
            guard let page = try await get(url, as: Page<Playlist?>.self) else { break }

            // A `null` here is an entry Spotify listed and would not describe.
            // It used to be compacted away, which is a deletion the listener
            // could not see and could not ask about: their library simply held
            // fewer playlists in Sorty than in Spotify. Nothing can be drawn for
            // it - there is no id, no name, no cover - but it can be counted,
            // and the count is what the library's footer says out loud.
            // ADR-0018.
            let described = page.items.compactMap(\.self)
            listing.withheldCount += page.items.count - described.count

            // Empty means Spotify *said* empty. It used to mean "reported no
            // count", and since February 2026 another listener's playlist
            // arrives with no count at all, so that reading deleted every one of
            // them from the library before it was ever drawn. See
            // `Playlist.trackCountIsKnown`.
            listing.playlists.append(contentsOf: described.filter { !$0.isReportedEmpty })
            if let total = page.total { listing.total = total }
            await onBatch(listing)
            next = page.next.flatMap(URL.init(string:))
        }
        return listing.playlists
    }

    public func playlistItems(
        playlistID: String,
        ownerID: String,
        onPage: @Sendable ([PlaylistItem], Int) async -> Void
    ) async throws -> [PlaylistItem] {
        var next: URL? = firstPage(of: itemsURL(playlistID: playlistID))
        var all: [PlaylistItem] = []
        // True only while the older spelling is being tried on speculation, so a
        // failure there can put the latch back the way it was found.
        var isProbingLegacyPath = false
        /// The refusal from the endpoint this app means to use, held across the
        /// probe so that a failed probe reports it rather than its own.
        var itemsRefusal: (any Error)?

        while let url = next {
            try Task.checkCancellation()
            let page: Page<PlaylistItem>?
            do {
                page = try await get(url, as: Page<PlaylistItem>.self)
            } catch let error as SpotifyAPIError
                where isPathUnsupported(error) && !usedLegacyItemsPath && !legacyPathIsRuledOut {
                // Either this Client ID predates /items, or this is a playlist
                // Spotify won't show anyone but its owner. Both answer 404, and
                // only trying the other spelling tells them apart - once.
                itemsRefusal = error
                usedLegacyItemsPath = true
                isProbingLegacyPath = true
                next = firstPage(of: legacyTracksURL(playlistID: playlistID))
                continue
            } catch {
                // The probe failed too, so the spelling was never the problem.
                // Leaving the latch set would point every later request in this
                // session at an endpoint March 2026 removed for Development Mode
                // apps, and the whole library would stop loading on the way back
                // from one playlist that was never readable.
                //
                // What the probe *proved* is kept, though: `/tracks` is not
                // available to this Client ID, and asking again on the next
                // refused playlist would spend a request to be told so twice.
                //
                // And the refusal reported is the one from the endpoint this app
                // means to use, not the 403 the removed spelling answers with -
                // which names a rule that is not the one refusing. The write
                // path has always done this; the read path said it did and
                // didn't.
                if isProbingLegacyPath {
                    usedLegacyItemsPath = false
                    legacyPathIsRuledOut = true
                    throw itemsRefusal ?? error
                }
                throw error
            }
            guard let page else { break }
            isProbingLegacyPath = false
            itemsRefusal = nil
            // A 200 that answers about the playlist and leaves its contents out.
            // Not an empty playlist: `items` is absent rather than empty, which
            // is how Spotify declines a playlist the listener neither owns nor
            // collaborates on.
            guard page.carriedItems else { throw SpotifyAPIError.contentsWithheld }
            let usable = page.items.filter { $0.track != nil }
            all.append(contentsOf: usable)
            await onPage(usable, all.count)
            next = page.next.flatMap(URL.init(string:))
        }
        return all
    }

    /// The first page of a playlist's contents, however the endpoint is spelled.
    private func firstPage(of endpoint: URL) -> URL {
        endpoint.appending(queryItems: [
            .init(name: "limit", value: "50"),
            .init(name: "additional_types", value: "track,episode"),
        ])
    }

    public func albums(ids: [String]) async throws -> [TrackAlbum] {
        guard !ids.isEmpty else { return [] }
        struct AlbumsResponse: Decodable { let albums: [TrackAlbum?] }

        var result: [TrackAlbum] = []
        // Reached only for an album that arrived without a release date, because a
        // track carries its album's `release_date` already - see
        // `TrackRow.albumReleaseDate`. So this whole path is a gap-filler now;
        // nothing routine depends on it succeeding.
        //
        // Batch /albums accepts 20 IDs per call, but February 2026 removed it for
        // newly registered apps. Try the batch, then degrade to one call per
        // album rather than losing every release date.
        //
        // The fallback fires on *any* API failure, not only the 404 that
        // `isPathUnsupported` recognises. That predicate exists for the two
        // spellings of the playlist-items endpoint, where a 403 genuinely means
        // "not allowed" and retrying the other spelling would mask it. Here the
        // single-album path is a different endpoint rather than a different
        // spelling, and the restriction this fallback was written for reports
        // itself as 403 - which the app's own copy says, in
        // `FeatureSourceMode.explanation`. Excluding 403 meant the degrade path
        // never ran in exactly the case it exists for, and every release date
        // came back empty.
        //
        // Once a whole batch has failed *and* its individual retries turned up
        // nothing, stop retrying: a permission failure applies to every album
        // alike, and a 300-album playlist would otherwise spend 300 requests
        // proving it.
        var individualRetriesAreFutile = false
        for batch in ids.chunked(into: 20) {
            let url = base.appending(path: "albums")
                .appending(queryItems: [.init(name: "ids", value: batch.joined(separator: ","))])
            do {
                if let response = try await get(url, as: AlbumsResponse.self) {
                    result.append(contentsOf: response.albums.compactMap(\.self))
                    continue
                }
            } catch is SpotifyAPIError {
                guard !individualRetriesAreFutile else { continue }
                let recovered = await albumsIndividually(ids: batch)
                individualRetriesAreFutile = recovered.isEmpty
                result.append(contentsOf: recovered)
                continue
            }
        }
        return result
    }

    /// Single-album fetches, run with bounded concurrency so a 300-album
    /// playlist doesn't open 300 sockets at once.
    private func albumsIndividually(ids: [String]) async -> [TrackAlbum] {
        await withTaskGroup(of: TrackAlbum?.self) { group in
            var collected: [TrackAlbum] = []
            var iterator = ids.makeIterator()
            var inFlight = 0
            let limit = 6

            func addNext() {
                guard let id = iterator.next() else { return }
                inFlight += 1
                group.addTask { [self] in
                    try? await get(base.appending(path: "albums/\(id)"), as: TrackAlbum.self)
                }
            }

            for _ in 0..<limit { addNext() }
            while inFlight > 0, let result = await group.next() {
                inFlight -= 1
                if let result { collected.append(result) }
                addNext()
            }
            return collected
        }
    }

    public func createPlaylist(
        userID: String,
        name: String,
        isPublic: Bool,
        description: String
    ) async throws -> Playlist {
        struct Body: Encodable {
            let name: String
            let `public`: Bool
            let description: String
        }
        let body = Body(name: name, public: isPublic, description: description)

        // February 2026 replaced POST /users/{id}/playlists with POST /me/playlists.
        do {
            return try await writeReturning(
                "POST", base.appending(path: "me/playlists"), body: body, as: Playlist.self
            )
        } catch let error as SpotifyAPIError where isPathUnsupported(error) {
            return try await writeReturning(
                "POST", base.appending(path: "users/\(userID)/playlists"), body: body, as: Playlist.self
            )
        }
    }

    public func replaceTracks(playlistID: String, uris: [String]) async throws {
        struct Body: Encodable { let uris: [String] }

        // The endpoint takes 100 URIs at a time. The first chunk PUTs, which
        // clears whatever was there; the rest POST to append in order.
        let chunks = uris.chunked(into: 100)
        guard !chunks.isEmpty else {
            try await writeToPlaylist("PUT", playlistID: playlistID, body: Body(uris: []))
            return
        }
        for (index, chunk) in chunks.enumerated() {
            try await writeToPlaylist(index == 0 ? "PUT" : "POST", playlistID: playlistID, body: Body(uris: chunk))
        }
    }

    private func writeToPlaylist<Body: Encodable>(
        _ method: String,
        playlistID: String,
        body: Body
    ) async throws {
        do {
            try await write(method, itemsURL(playlistID: playlistID), body: body)
        } catch let itemsError as SpotifyAPIError
            where isPathUnsupported(itemsError) && !usedLegacyItemsPath && !legacyPathIsRuledOut {
            // Latched only once the older spelling has actually worked, and the
            // refusal reported is the one from the endpoint this app means to
            // use. A 404 from a playlist that does not exist would otherwise
            // send the rest of the session to a removed endpoint.
            do {
                try await write(method, legacyTracksURL(playlistID: playlistID), body: body)
                usedLegacyItemsPath = true
            } catch {
                // Same question, same answer, and it does not need asking again.
                legacyPathIsRuledOut = true
                throw itemsError
            }
        }
    }

    // MARK: - Endpoint spelling

    private func itemsURL(playlistID: String) -> URL {
        usedLegacyItemsPath
            ? legacyTracksURL(playlistID: playlistID)
            : base.appending(path: "playlists/\(playlistID)/items")
    }

    private func legacyTracksURL(playlistID: String) -> URL {
        base.appending(path: "playlists/\(playlistID)/tracks")
    }

    /// 404 means "this Client ID doesn't have that spelling of the endpoint".
    /// 403 is deliberately excluded - that means "not allowed", and retrying a
    /// different path would just mask a genuine permission failure.
    private func isPathUnsupported(_ error: SpotifyAPIError) -> Bool {
        error.httpStatus == 404
    }
}
