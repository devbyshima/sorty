import Foundation

public enum SpotifyAPIError: LocalizedError {
    case notAuthenticated
    case http(status: Int, message: String?)
    case rateLimited(retryAfter: TimeInterval)
    case quotaExceeded
    case transport(any Error)
    case decoding(any Error)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "You're signed out. Sign in with Spotify to continue."
        case .http(let status, let message):
            if let message, !message.isEmpty { message } else { "Spotify returned an error (\(status))." }
        case .rateLimited(let retryAfter):
            "Spotify is rate limiting requests. Try again in \(Int(retryAfter.rounded()))s."
        case .quotaExceeded:
            "This Spotify app has used up its development-mode quota. Quota is shared across every app on your developer account and resets on Spotify's own schedule."
        case .transport(let error):
            "Network error: \(error.localizedDescription)"
        case .decoding:
            "Spotify sent a response Sortify couldn't read."
        }
    }

    /// Playlists owned by Spotify or by another user reject writes with 403/404.
    public var isNotWritable: Bool {
        if case .http(let status, _) = self { return status == 403 || status == 404 }
        return false
    }

    public var httpStatus: Int? {
        if case .http(let status, _) = self { return status }
        return nil
    }
}
