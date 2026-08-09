import Foundation

/// What to say when a connected account is on a token that predates a scope.
///
/// The words live here rather than in the view for the reason `EmptyState` and
/// `PlaylistRowText` do: they are the design, and they are the only part of this
/// that can be asserted. A notice nobody can test is a notice that quietly
/// becomes wrong.
public enum ReconnectNotice {
    /// The one case that exists so far, and the reason the type does.
    ///
    /// It has to explain an absence rather than an error. Nothing is broken on
    /// screen - shared playlists are simply not in any response, which looks
    /// exactly like not having any - so the sentence has to say what is missing,
    /// why, and that reconnecting is the whole fix.
    public static let collaborative = "Playlists shared with you aren't showing. Sorty needs one more permission from Spotify to see them - reconnecting grants it."

    public static let collaborativeAction = "Reconnect"
}
