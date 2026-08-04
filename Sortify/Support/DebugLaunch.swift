import Foundation

/// Launch-argument hooks for headless verification.
///
/// Screenshots are taken with `xcrun simctl io screenshot` against a running
/// simulator rather than by driving the simulator GUI, so the app has to be able
/// to *arrive* at a screen from a cold launch. These arguments do that.
///
/// DEBUG-only: the parsing and every call site compile out of release builds.
enum DebugLaunch {
    enum Screen: String {
        case landing, playlists, tracks, faq, settings
    }

    #if DEBUG
    /// `-screen tracks`
    static var screen: Screen? {
        UserDefaults.standard.string(forKey: "screen").flatMap(Screen.init)
    }

    /// `-playlist demo-longrun` — which demo playlist to open for `.tracks`.
    static var playlistID: String? {
        UserDefaults.standard.string(forKey: "playlist")
    }

    /// `-sort bpm -direction descending`
    static var sortColumn: SortColumn? {
        UserDefaults.standard.string(forKey: "sort").flatMap(SortColumn.init)
    }

    static var sortDirection: SortDirection? {
        UserDefaults.standard.string(forKey: "direction").flatMap(SortDirection.init)
    }

    static var isActive: Bool { screen != nil }
    #else
    static var screen: Screen? { nil }
    static var playlistID: String? { nil }
    static var sortColumn: SortColumn? { nil }
    static var sortDirection: SortDirection? { nil }
    static var isActive: Bool { false }
    #endif
}
