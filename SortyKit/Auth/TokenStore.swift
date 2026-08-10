import Foundation
import Security

public struct SpotifyTokens: Codable, Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String?
    public var expiresAt: Date
    /// What Spotify granted, not what was asked for.
    ///
    /// Optional because a token stored before this field existed decodes with
    /// nil.
    ///
    /// **Nothing in the app branches on it any more.** It fed a reconnect prompt
    /// for accounts on a token predating `playlist-read-collaborative`, which
    /// ADR-0017 removed along with the rest of the collaborative surfaces. It is
    /// kept because it is the only record of what a given token can actually do,
    /// it cannot be recovered for a token already in the Keychain, and dropping
    /// it would mean the next refresh quietly saved a token that had forgotten
    /// its own grant.
    public var grantedScopes: [String]?

    public init(
        accessToken: String,
        refreshToken: String?,
        expiresAt: Date,
        grantedScopes: [String]? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.grantedScopes = grantedScopes
    }

    /// Treated as expired a minute early so a request never starts with a token
    /// that dies mid-flight.
    public func isFresh(now: Date = Date()) -> Bool {
        now < expiresAt.addingTimeInterval(-60)
    }
}

public protocol TokenStoring: Sendable {
    func load() -> SpotifyTokens?
    func save(_ tokens: SpotifyTokens)
    func clear()
}

/// Keychain-backed storage.
///
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: the refresh token must
/// survive a relaunch, but must never ride an iCloud/iTunes backup onto another
/// device.
public struct KeychainTokenStore: TokenStoring {
    private let service: String
    private let account: String

    public init(service: String = "com.fulltimestudio.sorty", account: String = "spotify-tokens") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public func load() -> SpotifyTokens? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(SpotifyTokens.self, from: data)
    }

    public func save(_ tokens: SpotifyTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = baseQuery
            insert.merge(attributes) { current, _ in current }
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    public func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

/// Non-persistent store for tests and demo mode.
public final class InMemoryTokenStore: TokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: SpotifyTokens?

    public init(tokens: SpotifyTokens? = nil) { self.tokens = tokens }

    public func load() -> SpotifyTokens? {
        lock.withLock { tokens }
    }

    public func save(_ tokens: SpotifyTokens) {
        lock.withLock { self.tokens = tokens }
    }

    public func clear() {
        lock.withLock { tokens = nil }
    }
}
