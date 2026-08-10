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
        /// The settings sub-pages. Each is a push behind another push, so the
        /// harness has to be able to arrive with the whole stack standing -
        /// which is also what makes the back chevron in a captured build behave
        /// the way it will in a shipped one.
        case spotifyApp, audioFeatures, credits
        /// The guided connect flow of ticket 11, which a listener reaches by
        /// tapping Save in Demo Mode - so the harness has to arrive at it.
        case connect
        /// The way in, shown whenever no account is connected (ADR-0007).
        case signedOut
        /// Not a screen a listener reaches - the reorder measurement of ticket
        /// 09, which drives the real list at a size the demo catalogue has no
        /// playlist for.
        case profile
        /// The launch splash. It is a *state*, not a destination: it lives
        /// exactly as long as `session.restore()` takes, which against the demo
        /// catalogue is no time at all. Naming it holds it still long enough to
        /// be photographed, which is the only way to see whether the shader on
        /// the mark is running.
        case splash
    }

    enum Sheet: String {
        case arrangements, filter, track
    }

    #if DEBUG
    /// `-screen tracks`
    static var screen: Screen? {
        UserDefaults.standard.string(forKey: "screen").flatMap(Screen.init)
    }

    /// `-playlist demo-longrun` - which demo playlist to open for `.tracks`.
    static var playlistID: String? {
        UserDefaults.standard.string(forKey: "playlist")
    }

    /// `-arrangement bpm-descending`, `-arrangement artist-separation`.
    /// One argument, because an Arrangement is one thing - a column plus a
    /// separate direction could name a combination that doesn't exist.
    static var arrangement: Arrangement? {
        UserDefaults.standard.string(forKey: "arrangement").flatMap(Arrangement.init(argument:))
    }

    /// `-sheet arrangements` - a sheet can only be reached by tapping, and the
    /// harness never touches the simulator, so it has to arrive presented.
    static var sheet: Sheet? {
        UserDefaults.standard.string(forKey: "sheet").flatMap(Sheet.init)
    }

    /// `-connectStep clientID` - which step of the guided connect flow to
    /// arrive on. Steps are reached by tapping Continue, and the harness never
    /// taps, so the interesting ones - the redirect URI to copy, the Client ID
    /// field and its complaint - need naming directly.
    static var connectStep: ConnectStep? {
        UserDefaults.standard.string(forKey: "connectStep").flatMap { raw in
            ConnectStep.allCases.first { "\($0)" == raw }
        }
    }

    /// `-accent 5B4BE0` - overrides the identity colour for the length of one
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

    /// `-count 400` - how many tracks `-screen profile` builds its playlist
    /// from. The reorder threshold is a measurement, so the size has to be an
    /// input rather than whatever the demo catalogue happens to hold.
    static var profileCount: Int? {
        UserDefaults.standard.string(forKey: "count").flatMap(Int.init)
    }

    /// `-track 22` - which row `-sheet track` opens the detail sheet for,
    /// counted down the list as it appears. Position on screen rather than
    /// original index, so the harness can name a track from the unrankable
    /// group as easily as a ranked one.
    static var trackPosition: Int? {
        UserDefaults.standard.string(forKey: "track").flatMap(Int.init)
    }

    /// `-filter 300-400` - a tempo range, so a screen can be reached that would
    /// otherwise need scrolling. Tracks with no BPM always pass the filter, so
    /// a range nothing matches leaves exactly the unrankable ones on screen.
    static var filter: BPMFilter? {
        guard let raw = UserDefaults.standard.string(forKey: "filter") else { return nil }
        let bounds = raw.split(separator: "-").map { Int($0) }
        guard bounds.count == 2, let low = bounds[0], let high = bounds[1] else { return nil }
        return BPMFilter(minBPM: low, maxBPM: high, includeDoubled: false)
    }

    /// `-scrolled 260` - how far down the screen arrives, in points.
    ///
    /// The progressive blur exists only where content passes *under* a header,
    /// so a screen at rest has nothing to photograph and a screenshot of one
    /// proves only that the header is sharp. Arriving already scrolled is what
    /// makes the blur itself verifiable from a cold launch, which is the only
    /// kind of run this harness does.
    static var scrollOffset: CGFloat? {
        UserDefaults.standard.string(forKey: "scrolled").flatMap(Double.init).map { CGFloat($0) }
    }

    /// `-demo` - run against the bundled sample catalogue.
    ///
    /// **The only way into it.** ADR-0007 removed Demo Mode from the app, and
    /// the catalogue survives for this harness and for the tests. It is an
    /// explicit argument rather than a Debug-only default because a default
    /// means Debug and Release take different paths through the same launch
    /// code, which is exactly how a demo path survives into a shipped build
    /// unnoticed. Passing it is auditable; forgetting it fails loudly, with an
    /// empty library rather than a plausible one.
    static var usesDemoData: Bool {
        UserDefaults.standard.string(forKey: "demo") != nil
            || CommandLine.arguments.contains("-demo")
    }

    /// `-layout grid2` - which library layout to arrive in.
    ///
    /// It is a persisted preference, so without this the harness can only ever
    /// shoot whichever one the simulator happens to have been left in.
    static var libraryLayout: LibraryLayout? {
        UserDefaults.standard.string(forKey: "layout").flatMap(LibraryLayout.init(rawValue:))
    }

    /// `-stallLibrary 6` - hold the library's pages back this many seconds.
    ///
    /// The skeletons of ADR-0019 are on screen only while pages are in flight,
    /// and against the demo catalogue every page has landed before a screenshot
    /// could be taken - so the state they exist for is one no shot could ever
    /// catch. Same problem `-pendingCovers` solves, and the same answer.
    ///
    /// Only pages *after* the first are held, or the launch gate never opens and
    /// the shot is a photograph of the splash.
    static var libraryStall: Duration? {
        UserDefaults.standard.string(forKey: "stallLibrary")
            .flatMap(Double.init)
            .map { .milliseconds(Int($0 * 1000)) }
    }

    /// `-stallTracks 6` - hold a playlist's contents back this many seconds.
    ///
    /// Separate from `-stallLibrary`, and it has to be: `restore()` awaits the
    /// *whole* library load, and `applyDebugLaunchIfNeeded` runs after it - so
    /// stalling the library also stalls the navigation, and `-screen tracks`
    /// never leaves the library. One argument for each, so a shot can hold the
    /// thing it means to photograph and nothing else.
    static var trackStall: Duration? {
        UserDefaults.standard.string(forKey: "stallTracks")
            .flatMap(Double.init)
            .map { .milliseconds(Int($0 * 1000)) }
    }

    /// `-pendingCovers` - every cover stays unresolved for the whole launch.
    ///
    /// The ripple that stands in for a loading cover is, by design, on screen
    /// only until the file arrives, and against the demo catalogue covers are
    /// drawn on device in a frame or two. So the one state the shader exists
    /// for is the one state no screenshot could ever catch. This holds it.
    static var holdsCovers: Bool {
        CommandLine.arguments.contains("-pendingCovers")
    }

    /// `-advanceAfter 2` - move the connect flow on by one step, that many
    /// seconds after it appears.
    ///
    /// The page transition is the only way to see whether `pageSmear` resolved
    /// at all, and a step changes only when somebody taps - which this harness
    /// never does. Without this the shader could fail to load and the transition
    /// would quietly degrade to a plain slide, which looks perfectly fine and is
    /// exactly the silent failure ADR-0015 exists to catch.
    static var advanceAfter: Double? {
        UserDefaults.standard.string(forKey: "advanceAfter").flatMap(Double.init)
    }

    /// `-connectDetail` - arrive with a step's info sheet already open.
    ///
    /// Same reason as `-sheet`: it opens on a tap and this harness never taps,
    /// so the only way to photograph it is to be able to arrive presented.
    static var showsConnectDetail: Bool {
        CommandLine.arguments.contains("-connectDetail")
    }

    /// `-dashboard` - arrive with the in-app browser already open.
    ///
    /// Two taps in, so unreachable here for the usual reason. It earns an
    /// argument of its own beyond that, though: the browser is an
    /// `ASWebAuthenticationSession` rather than a view, and a session that
    /// declines to start does it *silently* - the button would simply do
    /// nothing, and the code that failed is a framework call with no visible
    /// output to check. This is the only way to see that the page opens at all.
    static var opensDashboard: Bool {
        CommandLine.arguments.contains("-dashboard")
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
    static var scrollOffset: CGFloat? { nil }
    static var libraryLayout: LibraryLayout? { nil }
    static var usesDemoData: Bool { false }
    static var libraryStall: Duration? { nil }
    static var trackStall: Duration? { nil }
    static var holdsCovers: Bool { false }
    static var advanceAfter: Double? { nil }
    static var showsConnectDetail: Bool { false }
    static var opensDashboard: Bool { false }
    static var isActive: Bool { false }
    #endif
}

// MARK: - Arriving scrolled

private struct DebugScrolled: ViewModifier {
    let offset: CGFloat?

    @State private var position = ScrollPosition()

    func body(content: Content) -> some View {
        if let offset {
            content
                .scrollPosition($position)
                // After a beat, not in `onAppear`: the scroll view has no
                // content extent yet when the view first appears, so a scroll
                // requested there is clamped to zero and silently does nothing.
                // The harness waits seconds before it shoots, so this is free.
                .task {
                    // Long enough to be after the screen's own `load()`, which
                    // rebuilds the list and resets the offset to zero. At 400ms
                    // it raced that and sometimes shot an unscrolled screen.
                    try? await Task.sleep(for: .milliseconds(1200))
                    // `scrollTo(y:)` and not `scrollTo(edge: .bottom)`, which
                    // was tried and is worse: with a tall `safeAreaInset` header
                    // the edge form lands past the content and the screen comes
                    // back empty. An absurd `y` clamps to the real bottom, which
                    // is what `-scrolled 99999` has always meant.
                    position.scrollTo(y: offset)
                }
        } else {
            content
        }
    }
}

extension View {
    /// Arrives at `-scrolled N` points down, for the headless harness.
    ///
    /// Outside DEBUG `DebugLaunch.scrollOffset` is always nil, so this resolves
    /// to the untouched scroll view - it does not bind a scroll position in a
    /// shipping build.
    func debugScrolled() -> some View {
        modifier(DebugScrolled(offset: DebugLaunch.scrollOffset))
    }
}
