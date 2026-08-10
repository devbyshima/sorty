import Foundation

/// The Appearance the user has chosen, which may be "whatever the device says".
///
/// `CONTEXT.md` defines Appearance as light or dark, followed from the device by
/// default and overridable. This is the override.
///
/// Here rather than beside `SortyTheme` because the *words* are copy, and the
/// house rule puts copy where a test can reach it: the app target is not
/// compiled into `SortyTheme`'s test target, so `label` could never be asserted
/// while it lived there. The `ColorScheme` half stays in the view layer, which
/// is the only half that needs SwiftUI - SortyKit imports it in no file and
/// should carry on not importing it.
public enum AppearanceChoice: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// The glyph the Appearance row wears, which *is* the current value.
    ///
    /// Settings draws it in the icon column that every other row uses for a
    /// fixed symbol, so the row answers "what is this set to" without being
    /// read - the same trick the trailing value on a navigation row plays, in
    /// the one place there is no navigation row to hang it on.
    public var symbolName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}
