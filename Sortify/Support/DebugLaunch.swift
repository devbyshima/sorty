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

    /// `-arrangement bpm-descending`, `-arrangement artist-separation`.
    /// One argument, because an Arrangement is one thing — a column plus a
    /// separate direction could name a combination that doesn't exist.
    static var arrangement: Arrangement? {
        UserDefaults.standard.string(forKey: "arrangement").flatMap(Arrangement.init(argument:))
    }

    static var isActive: Bool { screen != nil }
    #else
    static var screen: Screen? { nil }
    static var playlistID: String? { nil }
    static var arrangement: Arrangement? { nil }
    static var isActive: Bool { false }
    #endif
}
