import SwiftUI

/// The app.
///
/// ADR-0007 removed Demo Mode, so there are three states rather than a session
/// that always exists: connecting, signed out, and a connected library. The
/// signed-out screen is the front door - not a once-only welcome - and it is
/// where signing out lands too.
/// Everything the library stack can push.
///
/// The path was `[Playlist]` while a playlist was the only thing on the far side
/// of a push and Settings was a sheet. Settings is a page now - which is the
/// whole reason it stopped being a sheet, because a page can push and a sheet
/// could not - so the path has to hold more than one kind of thing.
enum LibraryRoute: Hashable {
    case playlist(Playlist)
    case settings
    case spotifyApp
    case audioFeatures
    case faq
    case credits
}

struct RootView: View {
    @Environment(SessionModel.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var path: [LibraryRoute] = []
    @State private var showingConnect = false
    @State private var didRestore = false
    /// The zoom that carries a playlist from the library into its tracks.
    ///
    /// Declared here rather than in `PlaylistsView` because a
    /// `.matchedTransitionSource` and the `.navigationTransition` that pairs with
    /// it have to share one namespace, and the two live on opposite sides of the
    /// `navigationDestination` below - the source is a tile in the library, the
    /// destination is built here. A namespace declared in the library could not
    /// be seen from the closure that builds the destination.
    @Namespace private var playlistZoom
    /// Holds the splash until there is a library behind it. ADR-0019.
    @State private var launch = LaunchGate()
    /// Appearance, as `CONTEXT.md` defines it: followed from the device unless
    /// the user says otherwise. Applied at the root so sheets inherit it, which
    /// they would not if it were applied per screen.
    @AppStorage("appearance") private var appearance: AppearanceChoice = .system

    var body: some View {
        Group {
            #if DEBUG
            // Short-circuits the whole session: the reorder measurement needs a
            // playlist the demo catalogue has no equivalent of, so it brings
            // its own service rather than signing in to anything.
            if DebugLaunch.screen == .profile {
                ReorderProfileView(count: DebugLaunch.profileCount ?? 200)
            } else if DebugLaunch.screen == .splash {
                // Held, rather than passed through. The splash is a state that
                // lasts as long as `restore()` does, and against the demo
                // catalogue that is no time at all.
                ConnectingView()
            } else {
                sessionContent
            }
            #else
            sessionContent
            #endif
        }
        .preferredColorScheme(appearance.colorScheme)
        // The splash, held over the app until there is something behind it.
        //
        // Above `sessionContent` rather than inside it, because what it now
        // waits for outlives the `.connecting` stage: `completeSignIn` sets
        // `stage = .ready` and *then* awaits the first page of playlists, so for
        // a beat the library exists and is empty. That beat is what this covers.
        // ADR-0019.
        .overlay {
            if launch.isCovering {
                ConnectingView()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(.easeOut(duration: 0.25), value: launch.isCovering)
        .onChange(of: session.launchProgress, initial: true) { _, progress in
            launch.update(progress, reduceMotion: reduceMotion)
        }
        // Both of the gate's deadlines. Watching `launchProgress` alone is not
        // enough in either direction - see `LaunchGate.run`.
        .task {
            await launch.run(progress: { session.launchProgress }, reduceMotion: reduceMotion)
        }
        // The connect flow cross-fades in.
        //
        // An overlay rather than a `sheet` or a `fullScreenCover`, because both
        // of those animate up from the bottom and iOS gives no way to change it.
        // The flow *is* the onboarding (`CONTEXT.md`) rather than an errand laid
        // on top of the app, and a modal rising from the bottom said the
        // opposite.
        //
        // It slid in from the right for a while. The fade is quieter and it is
        // also more honest about what happens: the way-in screen and the first
        // step are the same composition - the same glyph in the same place over
        // the same bloom - so sliding one off to reveal the other animated a
        // journey between two screens that mostly agree. Dissolving one into the
        // next lets the parts that match stay still.
        //
        // The overlay costs the free `dismiss()` a presentation gives, so
        // leaving is handed in as a closure - which is also what lets the back
        // chevron double as the way out (see `ConnectFlowView`).
        .overlay {
            if showingConnect {
                ConnectFlowView(onClose: { closeConnect() })
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: showingConnect)
        // Signing out tears the stack down but not the path that fed it: `path`
        // is this view's state and `library` only exists in the `.ready` branch
        // below, so the two part company. Without this, signing out from the
        // Settings page and connecting again would land the listener back on
        // whatever page they left - or on a playlist that is no longer in the
        // library at all.
        .onChange(of: session.stage) { _, stage in
            if stage != .ready { path.removeAll() }
        }
        .task {
            guard !didRestore else { return }
            didRestore = true
            await session.restore()
            await applyDebugLaunchIfNeeded()
        }
    }

    /// The stage change is what has to be animated, not the views.
    ///
    /// A `.transition` only plays when something animates the value that swapped
    /// the views, and `SessionModel` assigns `stage` bare in six places. So the
    /// `.transition(.opacity)` below sat here doing nothing, and the three
    /// screens cut between each other - including `ConnectingView`, which spends
    /// 0.45s settling its mark in and then vanished in a frame. Its own comment
    /// promises the launch, the connect screen and the library are "one
    /// continuous move rather than three flashes".
    ///
    /// Opacity only, so there is nothing to gate on Reduce Motion: a cross-fade
    /// is already the reduced-motion form of this.
    @ViewBuilder
    private var sessionContent: some View {
        Group {
            switch session.stage {
            case .connecting:
                // Only ever seen through the ceiling: while the gate covers,
                // this is behind it. Already settled, so a timeout reveals the
                // same image rather than re-animating one.
                ConnectingView(settles: false)
                    .transition(.opacity)

            case .signedOut:
                SignedOutView(onConnect: { showingConnect = true })
                    .transition(.opacity)

            case .ready:
                library
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: session.stage)
    }

    /// Leaving the connect flow. Animated here rather than at the call site so
    /// the fade out matches the fade in.
    ///
    /// A cross-fade needs no Reduce Motion branch: it is already the reduced
    /// form of every other transition in this app.
    private func closeConnect() {
        withAnimation(.easeInOut(duration: 0.28)) { showingConnect = false }
    }

    private var library: some View {
        NavigationStack(path: $path) {
            PlaylistsView(
                onSelect: { path.append(.playlist($0)) },
                onSettings: { path.append(.settings) },
                zoomNamespace: playlistZoom
            )
            // Every destination is registered here, on the root, so a push from
            // a pushed page needs nothing of its own: a `NavigationLink(value:)`
            // inside Settings finds this and appends. Declaring them per screen
            // would mean Settings owned a stack it does not own.
            .navigationDestination(for: LibraryRoute.self) { route in
                switch route {
                case .playlist(let playlist):
                    TrackListView(
                        model: session.makeTrackListModel(for: playlist),
                        onConnect: { showingConnect = true }
                    )
                    // The tile the listener touched grows into the screen it
                    // opens, rather than the screen sliding in over it from the
                    // right. Only this route takes it: a settings row is a line
                    // of text with no geometry worth carrying across, and zooming
                    // one would be motion applied for its own sake.
                    //
                    // No Reduce Motion branch here, and it is not an oversight -
                    // `.zoom` degrades to a cross-fade on its own when the
                    // setting is on, which is the same reduced form every other
                    // transition in this app falls back to.
                    .navigationTransition(.zoom(sourceID: playlist.id, in: playlistZoom))
                case .settings:
                    SettingsView(onConnect: { showingConnect = true })
                case .spotifyApp:
                    SpotifyAppSettingsView()
                case .audioFeatures:
                    AudioFeatureSettingsView()
                case .faq:
                    FAQView()
                case .credits:
                    CreditsView()
                }
            }
        }
    }

    /// Drives the app to a named screen on launch so each one can be captured
    /// headlessly. No-op in release builds.
    private func applyDebugLaunchIfNeeded() async {
        guard let screen = DebugLaunch.screen else { return }
        if let layout = DebugLaunch.libraryLayout {
            session.libraryLayout = layout
        }
        switch screen {
        case .signedOut:
            // Reached by not connecting, which is the default state, so there
            // is nothing to drive.
            break
        case .splash:
            // Short-circuited above, before any session exists to drive.
            break
        case .playlists:
            break
        // The whole stack, not just the visible screen, so the back chevron in a
        // captured build behaves the way it will in a shipped one.
        case .settings:
            path = [.settings]
        case .faq:
            path = [.settings, .faq]
        case .spotifyApp:
            path = [.settings, .spotifyApp]
        case .audioFeatures:
            path = [.settings, .audioFeatures]
        case .credits:
            path = [.settings, .credits]
        case .connect:
            showingConnect = true
        case .tracks:
            let target = DebugLaunch.playlistID.flatMap { id in
                session.playlists.first { $0.id == id }
            } ?? session.playlists.first
            guard let target else { break }
            // `-pushAfter` waits, so the push happens from a library that has
            // already drawn and settled - which is the only warm push this
            // harness can produce, and the only one whose frame timings say
            // anything about the transition rather than about process start.
            if let delay = DebugLaunch.pushAfter {
                try? await Task.sleep(for: .seconds(delay))
            }
            path = [.playlist(target)]
            if let back = DebugLaunch.popAfter {
                try? await Task.sleep(for: .seconds(back))
                path.removeLast()
            }
        case .profile:
            // Handled above, before the session is consulted at all.
            break
        }
    }

}

/// The one screen in Sorty that legitimately occupies the user while nothing
/// is on offer.
///
/// It is deliberately *not* a launch splash: a timed brand card would be
/// inventing a wait, which the Human Interface Guidelines rule out anyway. This
/// covers a real network round trip - a cold launch restoring a connected
/// session, or an authorisation coming back. A first run does not see it at all;
/// with no account there is nothing to restore, and ADR-0007 sends that straight
/// to `SignedOutView`.
///
/// It resembles the launch screen it replaces, which resembles the library it
/// leads to, so the three are one continuous move rather than three flashes.
struct ConnectingView: View {
    /// Whether the mark arrives, or is simply already there.
    ///
    /// The gate's copy is the one on screen from the first frame, so it settles.
    /// The copy `sessionContent` draws behind it is only ever revealed by the
    /// six-second ceiling, long after the settle finished above it - and a mark
    /// that re-scaled itself at that moment would turn a timeout into a
    /// visible glitch. Already-settled, the two are the same image.
    var settles = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = Float(timeline.date.timeIntervalSince(start))

            SortyMarkTile(side: 84)
                    .modifier(MarkShimmer(side: 84, time: t, on: !reduceMotion))
                    // The bloom is the mark's own accent thrown back onto the
                    // field, so the tile reads as lit rather than pasted on.
                    .shadow(color: SortyTheme.accent.opacity(settled ? 0.45 : 0),
                            radius: settled ? 30 : 0)
                    // Arrives rather than appears: one settle, spring-weighted
                    // so it overshoots a little and stops.
                .scaleEffect(settled || reduceMotion ? 1 : 0.72)
                .opacity(settled || reduceMotion ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { SplashBackdrop() }
        .ignoresSafeArea()
        .task {
            guard settles else { settled = true; return }
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.75, dampingFraction: 0.58)) { settled = true }
        }
        // The words are gone from the screen and kept for VoiceOver. Sighted
        // listeners get a mark on a field for a beat; a listener who cannot see
        // it would otherwise get an unlabelled screen that simply waits.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connecting to Spotify")
    }
}

/// The field the splash sits on: the app's own background with a single wide
/// bloom of accent rising from below the bottom edge.
///
/// Lifted from Beam's `SplashBackground`, in Sorty's colour. The circle is
/// pushed past the bottom on purpose - what shows is the top of a glow whose
/// source is off-screen, which is why it reads as light rather than as a shape.
struct SplashBackdrop: View {
    var body: some View {
        ZStack {
            SortyTheme.background
            Circle()
                .fill(SortyTheme.accent.gradient)
                .visualEffect { content, proxy in
                    content.offset(y: proxy.size.height * 1.07)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .blur(radius: 90)
        }
        .ignoresSafeArea()
    }
}

/// The sweep across the mark, applied only when motion is allowed.
private struct MarkShimmer: ViewModifier {
    let side: Double
    let time: Float
    let on: Bool

    func body(content: Content) -> some View {
        if on {
            content.layerEffect(
                ShaderLibrary.markShimmer(.float2(CGSize(width: side, height: side)), .float(time)),
                maxSampleOffset: .zero
            )
        } else {
            content
        }
    }
}
