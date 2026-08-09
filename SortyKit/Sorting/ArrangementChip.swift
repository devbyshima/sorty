import Foundation

/// One entry in the row of Arrangements above a playlist.
///
/// The row is computed rather than assembled in the view, because almost every
/// rule about it is a rule worth asserting: which five are pinned, that they
/// never move, that an off-piste Arrangement trails and then retires, that
/// direction shows only on the active chip, and that Shuffle's second tap does
/// not mean something different from BPM's. A chip carries the Arrangement it
/// would apply, so tapping one is a single unconditional call.
public struct ArrangementChip: Identifiable, Sendable, Hashable {
    public let basis: Arrangement.Basis
    public let isActive: Bool
    /// Shown on the chip itself, so direction never has to be inferred from the
    /// data. Nil unless this chip is the applied one *and* it has a direction.
    public let direction: Arrangement.Direction?
    /// True for the five that never move; false for a trailing off-piste chip.
    public let isPinned: Bool
    /// Shuffle, once applied, re-rolls from a control of its own rather than
    /// from the direction gesture - so tapping a chip twice always means the
    /// same thing whatever the chip is.
    public let showsReroll: Bool
    /// What tapping the chip body applies. For the active chip this flips the
    /// direction where there is one, and is a no-op where there isn't.
    public let tapped: Arrangement

    public var id: String { basis.rawValue }

    /// The five that are always within reach, in the order they always appear.
    /// Original order first because returning to where you started is the one
    /// action a listener needs most; BPM and Energy because they are what a
    /// playlist is usually reordered by.
    public static let pinned: [Arrangement.Basis] = [
        .attribute(.order), .attribute(.bpm), .attribute(.energy),
        .artistSeparation, .shuffle,
    ]

    /// Everything the picker sheet offers, in the order it offers it.
    public static var pickerBases: [Arrangement.Basis] { Arrangement.Basis.allCases }

    /// The chip row for what is currently applied: the five pinned, then a
    /// trailing chip when the applied Arrangement is not one of them. The
    /// trailing chip is derived, never accumulated, so it retires by
    /// construction the moment something else is applied.
    public static func row(for arrangement: Arrangement) -> [ArrangementChip] {
        let active = arrangement.basis
        var chips = pinned.map { chip(for: $0, applied: arrangement, isPinned: true) }
        if !pinned.contains(active) {
            chips.append(chip(for: active, applied: arrangement, isPinned: false))
        }
        return chips
    }

    private static func chip(
        for basis: Arrangement.Basis, applied: Arrangement, isPinned: Bool
    ) -> ArrangementChip {
        let isActive = basis == applied.basis
        return ArrangementChip(
            basis: basis,
            isActive: isActive,
            direction: isActive ? applied.direction : nil,
            isPinned: isPinned,
            showsReroll: isActive && basis == .shuffle,
            // An inactive chip always starts ascending: carrying the previous
            // Arrangement's direction across would make one chip's meaning
            // depend on another's state.
            tapped: isActive ? applied.reversed : basis.arrangement()
        )
    }
}
