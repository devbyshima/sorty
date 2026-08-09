import SwiftUI

/// The app.
///
/// ADR-0007 removed Demo Mode, so there are three states rather than a session
/// that always exists: connecting, signed out, and a connected library. The
/// signed-out screen is the front door - not a once-only welcome - and it is
/// where signing out lands too.
struct RootView: View {
    @Environment(SessionModel.self) private var session
    @State private var path: [Playlist] = []
    @State private var showingSettings = false
    @State private var showingFAQ = false
    @State private var showingConnect = false
    @State private var didRestore = false
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
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingFAQ) { FAQView() }
        .sheet(isPresented: $showingConnect) { ConnectFlowView() }
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
                ConnectingView()
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

    private var library: some View {
        NavigationStack(path: $path) {
            PlaylistsView(
                onSelect: { path.append($0) },
                onConnect: { showingConnect = true },
                onSettings: { showingSettings = true }
            )
            .navigationDestination(for: Playlist.self) { playlist in
                TrackListView(
                    model: session.makeTrackListModel(for: playlist),
                    onConnect: { showingConnect = true }
                )
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
        case .faq:
            showingFAQ = true
        case .settings:
            showingSettings = true
        case .connect:
            showingConnect = true
        case .tracks:
            let target = DebugLaunch.playlistID.flatMap { id in
                session.playlists.first { $0.id == id }
            } ?? session.playlists.first
            if let target { path = [target] }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = Float(timeline.date.timeIntervalSince(start))

            ZStack {
                SplashBackdrop()

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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .task {
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
