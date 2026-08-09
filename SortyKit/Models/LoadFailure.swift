import Foundation

/// Why a playlist wouldn't open, in words that mean something.
///
/// Spotify answers a great many refusals with a bare 403 and the word
/// "Forbidden", and `SpotifyAPIError` faithfully passes that through - which
/// put the raw word on screen with no hint of whose fault it was, what it
/// applied to, or whether trying again could ever help. The status alone never
/// says which refusal it is; the *playlist* says that, so this is resolved from
/// both together.
///
/// Since 27 November 2024 Spotify has blocked newly registered applications
/// from reading its own editorial and algorithmic playlists - Discover Weekly,
/// Release Radar, the Daily Mixes, and anything under the `spotify` account.
/// That is the single most likely reason a listener meets this, and it is not
/// something Sorty can work around.
public enum LoadFailure {

    public static func message(
        for error: any Error,
        playlist: Playlist,
        currentUserID: String?
    ) -> String {
        guard let apiError = error as? SpotifyAPIError, apiError.isNotWritable else {
            return error.localizedDescription
        }

        switch playlist.category(currentUserID: currentUserID) {
        case .personalized:
            return "Spotify doesn't let apps read playlists it makes for you, like Discover Weekly or your Daily Mixes. That's a restriction Spotify applies to every app registered since November 2024, and there is no way around it from here."
        case .spotify:
            return "This playlist belongs to Spotify, and Spotify doesn't let apps read its own editorial playlists. That's a restriction on their API rather than something Sorty can ask for."
        case .other:
            // The same sentence the library shows when it knows in advance, and
            // deliberately not a second wording of it: this is that rule
            // arriving from the wire instead of from the playlist, and a
            // listener meeting it twice should meet the same words.
            return EmptyState.contentsWithheld(owner: ownerName(of: playlist)).message
        case .mine:
            // Own playlist, refused anyway. Worth saying plainly that this one
            // is unexpected rather than dressing it as a rule.
            return "Spotify refused to send this playlist's tracks, which is unusual for a playlist you own. Signing out and connecting again is the thing most likely to help."
        }
    }

    /// Who Spotify says owns a playlist, or nil where it said nothing useful.
    /// A display name where there is one, the account name where there isn't,
    /// and nothing at all rather than an empty string that reads as a gap in a
    /// sentence.
    public static func ownerName(of playlist: Playlist) -> String? {
        let name = playlist.owner.displayName ?? playlist.owner.id
        return name.isEmpty ? nil : name
    }

    /// Whether retrying could plausibly work. A rule refusing every request
    /// alike will refuse the next one too, and a Try Again button that cannot
    /// succeed is worse than no button.
    public static func isWorthRetrying(
        _ error: any Error,
        playlist: Playlist,
        currentUserID: String?
    ) -> Bool {
        guard let apiError = error as? SpotifyAPIError, apiError.isNotWritable else {
            return true
        }
        return playlist.category(currentUserID: currentUserID) == .mine
    }
}
