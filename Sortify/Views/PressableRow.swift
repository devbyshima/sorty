import SwiftUI

/// The press response for a whole row or tile.
///
/// `.buttonStyle(.plain)` draws no press state at all, which left the two things
/// this app is mostly made of - a track row and a playlist tile - inert under a
/// finger, on screens where every chip, glass circle and menu reacts. It is the
/// same argument the overflow menu's own note makes about a pair of bar buttons
/// disagreeing: one control that lights up beside one that does not is the same
/// control behaving two ways.
///
/// **Deliberately almost invisible.** These are tapped constantly, and motion on
/// something seen that often reads as lag rather than as polish. 0.97 is the
/// subtle end of the press range and 0.14s is inside the 100-160ms budget.
///
/// **Reduce Motion gets the feedback without the movement.** A scale is a
/// position change; an opacity dip is not. Dropping the response entirely would
/// take the confirmation away from the people most likely to need it.
struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressedLabel(configuration: configuration)
    }

    /// A nested `View` rather than reading the environment on the style itself.
    ///
    /// `@Environment` on a `ButtonStyle` is not kept up to date: a style is not
    /// a view, so it captures whatever was current when it was created and never
    /// hears about a change. Reading it one level down, inside a real view, is
    /// what makes the Reduce Motion branch below actually track the setting.
    ///
    /// Deliberately not named `Body`. `ButtonStyle` has an associated type of
    /// that name, so a nested `Body` is read as satisfying the requirement and
    /// has to be as accessible as the style itself - which a `private` helper
    /// is not, and the conformance fails with an error that names the protocol
    /// rather than the collision.
    private struct PressedLabel: View {
        let configuration: ButtonStyleConfiguration

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1)
                .opacity(reduceMotion && configuration.isPressed ? 0.7 : 1)
                .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == PressableRowStyle {
    /// A row or tile that presses in under a finger.
    ///
    /// Only for the surfaces that carry no glass. Anything drawn with
    /// `.glassEffect(.regular.interactive(), in:)` already has the material's own
    /// press response, and stacking a scale on top of it would double the effect.
    static var pressableRow: PressableRowStyle { PressableRowStyle() }
}
