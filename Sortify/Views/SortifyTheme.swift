import SwiftUI

/// Sortify's colours, as tokens rather than as one accent and two system greys.
///
/// Each is named for the job it does, not for what it looks like, so a change of
/// identity is a change here and nowhere else. The system drives light and dark
/// for everything the system has a good answer for — backgrounds, separators,
/// label hierarchy — because those are the colours Liquid Glass composites
/// against and hard-coding them is how an app stops looking like it belongs on
/// the phone.
enum SortifyTheme {

    /// The identity. Everything Sortify itself asserts — the applied chip, a
    /// value the Arrangement sorted by, a position bar's fill.
    ///
    /// Deliberately not green. The accent this replaces was Spotify's brand
    /// green with eighteen points of blue added, sharing Spotify's exact red
    /// and green channel values — near enough to read as first-party, which
    /// misattributed every rough edge in the app to Spotify. See ADR-0006.
    static var accent: Color {
        #if DEBUG
        if let override = DebugLaunch.accent { return override }
        #endif
        return Color("AccentColor")
    }

    /// Text and glyphs *on* the accent — the applied chip's label.
    ///
    /// Adapts, and has to. The light accent is dark enough that white sits at
    /// 5.95:1 on it; the dark accent is lifted to clear the dark card, which
    /// leaves white at 3.29:1 and near-black at 6.37:1. No single foreground
    /// clears AA against both, which is why this is a token rather than
    /// `.white` written at the call site. See ADR-0006 for the arithmetic.
    static var onAccent: Color { Color(.systemBackground) }

    /// The unfilled part of a position bar, and any accent-shaped surface that
    /// is present but not asserting anything.
    static var accentTrack: some ShapeStyle { Color.primary.opacity(0.12) }

    /// Spotify's own green, for the two places it is correct: the affordance
    /// that connects an account, and required attribution.
    ///
    /// A constant rather than an asset colour, because it is *their* value and
    /// must not drift with our identity. #1DB954.
    static let spotifyGreen = Color(red: 0.114, green: 0.725, blue: 0.329)

    static var background: some ShapeStyle { Color(.systemGroupedBackground) }
    static var surface: some ShapeStyle { Color(.secondarySystemGroupedBackground) }
    static var separator: Color { Color(.separator) }
}
