import Foundation

public struct SpotifyAuthConfig: Sendable {
    public let clientID: String
    public let redirectURI: String
    public let scopes: [String]

    /// Enough to read playlists and write the sorted result back, and nothing
    /// more.
    ///
    /// **`playlist-read-collaborative` is not optional.** Without it Spotify
    /// omits collaborative playlists you are a member of from `/me/playlists`
    /// entirely - they are not misclassified, they never arrive - so the
    /// Collaborative chip is empty and no shared playlist can be arranged. The
    /// first three were "the same three the reference app uses"; the reference
    /// app does not offer a Collaborative filter.
    public static let requiredScopes = [
        "playlist-read-private",
        "playlist-read-collaborative",
        "playlist-modify-private",
        "playlist-modify-public",
    ]

    public init(clientID: String, redirectURI: String, scopes: [String] = requiredScopes) {
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.scopes = scopes
    }

    public var callbackScheme: String? {
        URL(string: redirectURI)?.scheme
    }
}

public enum SpotifyAuthError: LocalizedError, Equatable {
    case notConfigured
    case cancelled
    case denied(String)
    case stateMismatch
    case missingCode
    case tokenExchangeFailed(String)
    case noRefreshToken

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Sorty has no Spotify client ID. Add one in Settings to connect your account."
        case .cancelled:
            "Sign-in was cancelled."
        case .denied(let reason):
            "Spotify denied the request: \(reason)"
        case .stateMismatch:
            "Sign-in response didn't match the request. Please try again."
        case .missingCode:
            "Spotify didn't return an authorization code."
        case .tokenExchangeFailed(let detail):
            "Couldn't complete sign-in: \(detail)"
        case .noRefreshToken:
            "Your session expired. Please sign in again."
        }
    }
}

/// Builds the authorize URL, exchanges the code, and refreshes tokens.
///
/// Deliberately knows nothing about presenting a browser - the app target owns
/// `ASWebAuthenticationSession` and hands the callback URL back here, which
/// keeps this whole type testable without a UI.
public actor SpotifyAuthenticator {
    public let config: SpotifyAuthConfig
    private let store: any TokenStoring
    private let session: URLSession

    private var pendingVerifier: String?
    private var pendingState: String?
    /// Coalesces concurrent refreshes so ten parallel requests hitting a 401 all
    /// wait on one token call instead of racing to invalidate each other.
    private var refreshTask: Task<SpotifyTokens, any Error>?

    private static let authorizeEndpoint = URL(string: "https://accounts.spotify.com/authorize")!
    private static let tokenEndpoint = URL(string: "https://accounts.spotify.com/api/token")!

    public init(config: SpotifyAuthConfig, store: any TokenStoring, session: URLSession = .shared) {
        self.config = config
        self.store = store
        self.session = session
    }

    public var isSignedIn: Bool {
        store.load() != nil
    }

    // MARK: - Authorize

    public func makeAuthorizationURL() -> URL {
        let verifier = PKCE.codeVerifier()
        let state = PKCE.state()
        pendingVerifier = verifier
        pendingState = state

        var components = URLComponents(url: Self.authorizeEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "client_id", value: config.clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: config.redirectURI),
            .init(name: "scope", value: config.scopes.joined(separator: " ")),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: PKCE.codeChallenge(for: verifier)),
            .init(name: "state", value: state),
        ]
        return components.url!
    }

    /// Completes the flow from the URL the callback delivered.
    @discardableResult
    public func handleCallback(url: URL) async throws -> SpotifyTokens {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw SpotifyAuthError.missingCode
        }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        if let error = value("error") {
            throw error == "access_denied" ? SpotifyAuthError.cancelled : SpotifyAuthError.denied(error)
        }
        guard let returnedState = value("state"), returnedState == pendingState else {
            throw SpotifyAuthError.stateMismatch
        }
        guard let code = value("code") else { throw SpotifyAuthError.missingCode }
        guard let verifier = pendingVerifier else { throw SpotifyAuthError.stateMismatch }

        pendingVerifier = nil
        pendingState = nil

        return try await exchange(code: code, verifier: verifier)
    }

    private func exchange(code: String, verifier: String) async throws -> SpotifyTokens {
        let body = [
            "client_id": config.clientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI,
            "code_verifier": verifier,
        ]
        let tokens = try await postToken(body)
        store.save(tokens)
        return tokens
    }

    // MARK: - Tokens

    /// A token guaranteed fresh, refreshing first if needed.
    public func validAccessToken() async throws -> String {
        if let tokens = store.load(), tokens.isFresh() {
            return tokens.accessToken
        }
        return try await refresh().accessToken
    }

    @discardableResult
    public func refresh() async throws -> SpotifyTokens {
        if let refreshTask {
            return try await refreshTask.value
        }

        guard let existing = store.load(), let refreshToken = existing.refreshToken else {
            throw SpotifyAuthError.noRefreshToken
        }

        let task = Task<SpotifyTokens, any Error> { [config, store] in
            let body = [
                "client_id": config.clientID,
                "grant_type": "refresh_token",
                "refresh_token": refreshToken,
            ]
            var tokens = try await self.postToken(body)
            // A refresh response often omits `scope`. Carrying the previous
            // grant forward stops a refresh from looking like a downgrade and
            // raising a reconnect prompt against a perfectly good token.
            if tokens.grantedScopes == nil {
                tokens.grantedScopes = existing.grantedScopes
            }
            // Spotify only sometimes rotates the refresh token; hold on to the
            // old one when it doesn't, or the next refresh has nothing to use.
            if tokens.refreshToken == nil {
                tokens.refreshToken = refreshToken
            }
            store.save(tokens)
            return tokens
        }
        refreshTask = task

        defer { refreshTask = nil }
        do {
            return try await task.value
        } catch {
            // A refresh token Spotify rejects is dead - drop it so the UI falls
            // back to the sign-in screen instead of retrying forever.
            if case SpotifyAuthError.tokenExchangeFailed = error {
                store.clear()
            }
            throw error
        }
    }

    public func signOut() {
        store.clear()
        pendingVerifier = nil
        pendingState = nil
    }

    // MARK: - Token endpoint

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Double
        /// Space-separated, and what Spotify actually granted rather than what
        /// was asked for. Absent on some refresh responses, which is why the
        /// refresh path carries the previous value forward.
        let scope: String?
    }

    private struct TokenErrorResponse: Decodable {
        let error: String?
        let error_description: String?
    }

    private func postToken(_ fields: [String: String]) async throws -> SpotifyTokens {
        var request = URLRequest(url: Self.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SpotifyAuthError.tokenExchangeFailed("no response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode(TokenErrorResponse.self, from: data))
                .flatMap { $0.error_description ?? $0.error } ?? "HTTP \(http.statusCode)"
            throw SpotifyAuthError.tokenExchangeFailed(detail)
        }

        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        return SpotifyTokens(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token,
            expiresAt: Date().addingTimeInterval(decoded.expires_in),
            grantedScopes: decoded.scope.map { $0.split(separator: " ").map(String.init) }
        )
    }
}
