import Foundation
import SwiftUI

/// Launch-argument hooks for headless verification.
///
/// Screenshots are taken with `xcrun simctl io screenshot` against a running
/// simulator rather than by driving the simulator GUI, so the app has to be able
/// to *arrive* at a screen from a cold launch. These arguments do that.
///
/// DEBUG-only: the parsing and every call site compile out of release builds.
enum DebugLaunch {
    enum Screen: String {
        case playlists, tracks, faq, settings
        /// The guided connect flow of ticket 11, which a listener reaches by
        /// tapping Save in Demo Mode — so the harness has to arrive at it.
        case connect
        /// Not a screen a listener reaches — the reorder measurement of ticket
        /// 09, which drives the real list at a size the demo catalogue has no
        /// playlist for.
        case profile
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

    /// `-connectStep clientID` — which step of the guided connect flow to
    /// arrive on. Steps are reached by tapping Continue, and the harness never
    /// taps, so the interesting ones — the redirect URI to copy, the Client ID
    /// field and its complaint — need naming directly.
    static var connectStep: ConnectStep? {
        UserDefaults.standard.string(forKey: "connectStep").flatMap { raw in
            ConnectStep.allCases.first { "\($0)" == raw }
        }
    }

    /// `-accent 5B4BE0` — overrides the identity colour for the length of one
    /// launch.
    ///
    /// A colour cannot be judged in the abstract; it has to be seen against
    /// real cover artwork at real size, in both appearances, beside the
    /// position bars. This is what let the candidates be shot side by side from
    /// one build instead of one build each.
    static var accent: Color? {
        guard let hex = UserDefaults.standard.string(forKey: "accent"),
              hex.count == 6,
              let value = UInt32(hex, radix: 16)
        else { return nil }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// `-count 400` — how many tracks `-screen profile` builds its playlist
    /// from. The reorder threshold is a measurement, so the size has to be an
    /// input rather than whatever the demo catalogue happens to hold.
    static var profileCount: Int? {
        UserDefaults.standard.string(forKey: "count").flatMap(Int.init)
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
    static var profileCount: Int? { nil }
    static var connectStep: ConnectStep? { nil }
    static var filter: BPMFilter? { nil }
    static var isActive: Bool { false }
    #endif
}
