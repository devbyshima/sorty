import SwiftUI

/// Sortify's colours, as tokens rather than as one accent and two system greys.
///
/// Each is named for the job it does, not for what it looks like, so a change of
/// identity is a change here and nowhere else.
///
/// **Both Appearances are authored.** The first pass drove everything from
/// `systemGroupedBackground` and `secondarySystemGroupedBackground`, which in
/// dark gives real separation for free and in light gives grey on barely
/// distinguishable grey. Light was therefore the Appearance the app actually
/// shipped in and the one nobody had designed. It now gets its own values:
/// a near-white field with genuinely white cards above it, and a hairline to
/// carry the edges that luminance alone carries in dark.
enum SortifyTheme {

    /// The identity. Everything Sortify itself asserts - the applied chip, a
    /// value the Arrangement sorted by, a position bar's fill.
    ///
    /// Deliberately not green. See ADR-0006.
    static var accent: Color {
        #if DEBUG
        if let override = DebugLaunch.accent { return override }
        #endif
        return Color("AccentColor")
    }

    /// Text and glyphs *on* the accent. Adapts, and has to: no single
    /// foreground clears AA against both accent variants. See ADR-0006.
    static var onAccent: Color { Color(.systemBackground) }

    /// The unfilled part of a position bar, and any accent-shaped surface that
    /// is present but not asserting anything.
    static var accentTrack: some ShapeStyle { Color.primary.opacity(0.12) }

    /// Spotify's own green, for the two places it is correct: the affordance
    /// that connects an account, and required attribution. A constant rather
    /// than an asset colour, because it is *their* value and must not drift
    /// with our identity. #1DB954.
    static let spotifyGreen = Color(red: 0.114, green: 0.725, blue: 0.329)

    // MARK: - Surfaces

    /// The field everything sits on.
    static var background: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.05, alpha: 1)
                : UIColor(red: 0.957, green: 0.957, blue: 0.969, alpha: 1)
        })
    }

    /// A card, a chip at rest, a sheet's content. Sits *above* `background` and
    /// has to be seen to do so in both Appearances: lighter than the field in
    /// dark, and pure white against a tinted field in light.
    static var surface: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.14, alpha: 1)
                : UIColor(white: 1, alpha: 1)
        })
    }

    /// One step further up: a chip on top of a card, a control on a header.
    static var raisedSurface: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.21, alpha: 1)
                : UIColor(red: 0.925, green: 0.925, blue: 0.945, alpha: 1)
        })
    }

    /// Edges. Light needs these to express elevation at all; dark needs them
    /// only faintly, because luminance is already doing the work.
    static var hairline: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.10)
                : UIColor(white: 0, alpha: 0.09)
        })
    }

    /// The shadow under a card. Absent in dark, where a cast shadow on a
    /// near-black field is invisible at best and a grey smear at worst.
    static func cardShadow(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .clear : Color.black.opacity(0.06)
    }

    static var separator: Color { hairline }
}

/// The Appearance the user has chosen, which may be "whatever the device says".
///
/// `CONTEXT.md` defines Appearance as light or dark, followed from the device by
/// default and overridable. This is the override.
enum AppearanceChoice: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Nil means "follow the device", which is what `preferredColorScheme`
    /// already understands.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
