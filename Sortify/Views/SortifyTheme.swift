import SwiftUI

/// A small, deliberate palette. The reference app is a dark table with a green
/// accent; this keeps that character while letting the system drive light and
/// dark so Liquid Glass has real material to work against.
enum SortifyTheme {
    static let accent = Color("AccentColor")

    static var background: some ShapeStyle { Color(.systemGroupedBackground) }
    static var surface: some ShapeStyle { Color(.secondarySystemGroupedBackground) }

    /// Row striping in the table — subtle enough to read across 15 columns.
    static func rowFill(isAlternate: Bool) -> Color {
        isAlternate ? Color(.tertiarySystemGroupedBackground).opacity(0.5) : .clear
    }

    static let tableRowHeight: CGFloat = 40
    static let tableHeaderHeight: CGFloat = 38
}

extension View {
    /// Numbers in the table need to line up column to column; proportional
    /// digits make a sorted column look ragged.
    func tabularNumbers() -> some View {
        monospacedDigit()
    }
}
