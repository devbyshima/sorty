import SwiftUI

/// A small, deliberate palette, letting the system drive light and dark so
/// Liquid Glass has real material to work against.
enum SortifyTheme {
    static let accent = Color("AccentColor")

    static var background: some ShapeStyle { Color(.systemGroupedBackground) }
    static var surface: some ShapeStyle { Color(.secondarySystemGroupedBackground) }
}
