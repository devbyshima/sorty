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
    static var glassEdge: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.06)
                : UIColor(white: 0, alpha: 0.12)
        })
    }
}

extension View {
    /// Draws `SortifyTheme.glassEdge` around a glass surface.
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
        overlay(shape.strokeBorder(isEnabled ? SortifyTheme.glassEdge : .clear, lineWidth: 1))
    }
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
