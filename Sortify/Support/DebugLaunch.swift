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

    enum Sheet: String {
        case arrangements, filter, track
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

    /// `-sheet arrangements` — a sheet can only be reached by tapping, and the
    /// harness never touches the simulator, so it has to arrive presented.
    static var sheet: Sheet? {
        UserDefaults.standard.string(forKey: "sheet").flatMap(Sheet.init)
    }

    /// `-track 22` — which row `-sheet track` opens the detail sheet for,
    /// counted down the list as it appears. Position on screen rather than
    /// original index, so the harness can name a track from the unrankable
    /// group as easily as a ranked one.
    static var trackPosition: Int? {
        UserDefaults.standard.string(forKey: "track").flatMap(Int.init)
    }

    /// `-filter 300-400` — a tempo range, so a screen can be reached that would
    /// otherwise need scrolling. Tracks with no BPM always pass the filter, so
    /// a range nothing matches leaves exactly the unrankable ones on screen.
    static var filter: BPMFilter? {
        guard let raw = UserDefaults.standard.string(forKey: "filter") else { return nil }
        let bounds = raw.split(separator: "-").map { Int($0) }
        guard bounds.count == 2, let low = bounds[0], let high = bounds[1] else { return nil }
        return BPMFilter(minBPM: low, maxBPM: high, includeDoubled: false)
    }

    static var isActive: Bool { screen != nil }
    #else
    static var screen: Screen? { nil }
    static var playlistID: String? { nil }
    static var arrangement: Arrangement? { nil }
    static var sheet: Sheet? { nil }
    static var trackPosition: Int? { nil }
    static var filter: BPMFilter? { nil }
    static var isActive: Bool { false }
    #endif
}
