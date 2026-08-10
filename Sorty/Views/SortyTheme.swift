import SwiftUI

/// Sorty's colours, as tokens rather than as one accent and two system greys.
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
enum SortyTheme {

    /// The identity. Everything Sorty itself asserts - the applied chip, a
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

    /// The edge a glass surface needs in light and barely needs in dark.
    ///
    /// **Measured, from the harness set.** A chip at rest composites to
    /// L\* 97.3 on a light field of L\* 96.3, and to L\* 15.2 on a dark field of
    /// L\* 3.6: one step of separation in light against about twelve in dark.
    /// Liquid Glass lifts off its background by *lightening*, and a near-white
    /// field gives it nowhere to lift to, so in light the capsules read as
    /// floating labels rather than as things to press.
    ///
    /// This is the rule the rest of this file already states - light carries
    /// elevation with edges where dark carries it with luminance - applied to
    /// the one family of surfaces that never got one. It is deliberately not
    /// the 3:1 boundary WCAG 1.4.11 would ask of a control identified *by* its
    /// outline: these are identified by their label, which clears AA, and by an
    /// accent fill when applied, which is unmistakable in both Appearances. The
    /// edge is here to make a capsule read as an object, not to carry meaning,
    /// and an outline heavy enough for 3:1 would turn a delicate row of chips
    /// into a row of bordered buttons.
    /// **Nothing at all in dark, and that is what the measurement said.** Dark
    /// glass already separates from its field by about twelve L\* steps against
    /// light's one, so it never needed an edge; a token white 6% was added
    /// anyway, for symmetry rather than for a reason, and on a dark capsule it
    /// reads as a second outline drawn inside the material's own. Removing it
    /// leaves dark exactly as it was before ADR-0011, which is where the
    /// measurement already put it.
    static var glassEdge: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? .clear
                : UIColor(white: 0, alpha: 0.12)
        })
    }

    /// The accent as a *field* rather than as an assertion: the account card at
    /// the head of Settings, and anything else that wants to be identifiably
    /// Sorty's without claiming a value the way `accent` does.
    ///
    /// Authored per Appearance rather than written as `accent.opacity(0.15)`,
    /// for the reason the rest of this file gives: the accent is not one colour.
    /// It is #5B4BE0 on a near-white field in light and #8B7BFF on a near-black
    /// one in dark, and one alpha over those two gives a pale lavender in the
    /// first and a bruise in the second. These two were picked against their own
    /// backgrounds.
    static var accentWash: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.545, green: 0.482, blue: 1, alpha: 0.16)
                : UIColor(red: 0.357, green: 0.294, blue: 0.878, alpha: 0.11)
        })
    }

    /// The dotted line between two rows of a settings card.
    ///
    /// **Not `hairline`, and the difference is measured in ink.** `hairline` is
    /// calibrated for a continuous one-pixel rule; a 1.5-on-5 dash lays down
    /// about a quarter of those pixels, so at black 9% it is not a quieter
    /// divider in light, it is an absent one. This is the same line given back
    /// the contrast the dashes cost it.
    static var dottedSeparator: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.20)
                : UIColor(white: 0, alpha: 0.18)
        })
    }

    /// Signing out, and nothing else so far.
    ///
    /// A token rather than `.red` at the call site, for this file's stated
    /// reason: a change of identity should be a change here, not a search.
    static var destructive: Color { Color(.systemRed) }
}

extension View {
    /// Draws `SortyTheme.glassEdge` around a glass surface.
    ///
    /// Every `.glassEffect` in the app is followed by one of these, in the same
    /// shape, so that a capsule and a circle are edged the same way and no
    /// call site decides how much edge it wants. `strokeBorder` rather than
    /// `stroke`: an inset border stays inside the material instead of
    /// straddling it and reading a pixel wider than the shape it traces.
    ///
    /// **Pass `false` where an accent fill sits under the glass.** The edge
    /// exists so a *clear* capsule reads as an object on a near-white field;
    /// over the accent there is already a hard colour boundary doing that job,
    /// and the stroke stops reading as an edge and starts reading as a dark
    /// line drawn inside the control. ADR-0011 makes the measurement and its
    /// correction records this exemption.
    ///
    /// Expressed as a colour rather than as an `if`, so the view tree is the
    /// same shape whichever way it goes and a chip does not change identity at
    /// the moment it is applied - which is the moment it is also animating.
    func glassEdge(in shape: some InsettableShape, isEnabled: Bool = true) -> some View {
        overlay(shape.strokeBorder(isEnabled ? SortyTheme.glassEdge : .clear, lineWidth: 1))
    }
}

extension AppearanceChoice {
    /// Nil means "follow the device", which is what `preferredColorScheme`
    /// already understands.
    ///
    /// The rest of the type lives in `SortyKit/Models/Appearance.swift`, where
    /// its words can be tested. This half stays here because `ColorScheme` is
    /// SwiftUI's and SortyKit does not import SwiftUI.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
