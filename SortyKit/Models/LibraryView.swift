import Foundation

/// How the library of playlists is ordered.
///
/// Deliberately not called a sort. `CONTEXT.md` reserves that vocabulary for
/// what happens *inside* a playlist, where an Arrangement is the first-class
/// thing a user picks. Ordering the library is a different job on a different
/// noun, and giving it the same word would blur the one distinction the app is
/// built around.
public enum LibraryOrder: String, CaseIterable, Sendable, Identifiable, Hashable {
    /// The order the service returned, which for Spotify is the listener's own
    /// library order and reads as most-recent-first. Honest about what it is:
    /// Sorty is never told when a playlist was added, so this claims no more
    /// than "the order they arrived in".
    case recents
    case name
    case size

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .recents: "Recents"
        case .name: "Name"
        case .size: "Track count"
        }
    }

    public var symbolName: String {
        switch self {
        case .recents: "clock"
        case .name: "textformat"
        case .size: "number"
        }
    }

    public func apply(to playlists: [Playlist]) -> [Playlist] {
        switch self {
        case .recents:
            return playlists
        case .name:
            return playlists.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .size:
            // Largest first: "which of these is the big one" is the question
            // this order gets asked, and a run of empty playlists at the top
            // answers it backwards. Ties fall back to name so the order is
            // total rather than merely deterministic-by-luck.
            return playlists.sorted {
                $0.tracks.total == $1.tracks.total
                    ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    : $0.tracks.total > $1.tracks.total
            }
        }
    }
}

/// How the library is laid out.
public enum LibraryLayout: String, CaseIterable, Sendable, Identifiable, Hashable {
    /// Two covers to a row, each about twice the area of `grid`'s, and the
    /// default.
    ///
    /// The first redesign removed a two-up grid on the measurement that a list
    /// showed about seven playlists per screen against its four. Density lost
    /// that argument here: the covers are the only thing on this screen worth
    /// looking at, and three-up shrinks them to thumbnails.
    case gridTwo = "grid2"
    /// Three covers to a row, matching the reference the screen was rebuilt
    /// against.
    case grid
    case list

    public var id: String { rawValue }

    /// What this layout is called. Used by the picker in the toolbar menu,
    /// where each option names itself and the selected one is ticked.
    ///
    /// Named by the size of the thing you get rather than by a column count,
    /// which is what a listener is actually choosing between.
    public var label: String {
        switch self {
        case .gridTwo: "Large grid"
        case .grid: "Small grid"
        case .list: "List"
        }
    }

    public var symbolName: String {
        switch self {
        case .gridTwo: "square.grid.2x2"
        case .grid: "square.grid.3x3"
        case .list: "list.bullet"
        }
    }

    /// How many covers to a row, or nil for the list.
    public var columns: Int? {
        switch self {
        case .gridTwo: 2
        case .grid: 3
        case .list: nil
        }
    }
}

/// Remembers the library's presentation between launches.
///
/// Preferences rather than state: losing them is harmless, so this never fails
/// and never reports an error. A garbage value falls back to the default rather
/// than propagating.
/// `UserDefaults` is thread-safe by documented contract but is not marked
/// `Sendable`, so the promise is made here rather than dropped.
public struct LibraryPreferences: @unchecked Sendable {
    private let defaults: UserDefaults
    private static let orderKey = "library.order"
    private static let layoutKey = "library.layout"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var order: LibraryOrder {
        get { defaults.string(forKey: Self.orderKey).flatMap(LibraryOrder.init(rawValue:)) ?? .recents }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.orderKey) }
    }

    public var layout: LibraryLayout {
        get { defaults.string(forKey: Self.layoutKey).flatMap(LibraryLayout.init(rawValue:)) ?? .gridTwo }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.layoutKey) }
    }
}
