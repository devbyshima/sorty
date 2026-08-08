import Foundation

public enum SpotifyAPIError: LocalizedError {
    case notAuthenticated
    case http(status: Int, message: String?)
    case rateLimited(retryAfter: TimeInterval)
    case quotaExceeded
    case transport(any Error)
    case decoding(any Error)
    /// Spotify answered about the playlist but sent no contents: a 200 whose
    /// `items` array is absent rather than empty. The documented shape for a
    /// playlist the listener neither owns nor collaborates on, alongside the
    /// 403 the items endpoint itself returns.
    case contentsWithheld

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
        case .contentsWithheld:
            "Spotify didn't send this playlist's tracks."
        }
    }

    /// Whether this is Spotify refusing rather than failing: the statuses it
    /// answers a rule with, plus the contents it silently leaves out.
    ///
    /// Named for writes because that is where it started, and read now by every
    /// refusal - `LoadFailure` turns one of these into a sentence that says
    /// *which* rule, which the status alone never does.
    public var isNotWritable: Bool {
        if case .http(let status, _) = self { return status == 403 || status == 404 }
        if case .contentsWithheld = self { return true }
        return false
    }

    public var httpStatus: Int? {
        if case .http(let status, _) = self { return status }
        return nil
    }
}
