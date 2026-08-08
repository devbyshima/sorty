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

    @ViewBuilder
    private var sessionContent: some View {
        switch session.stage {
        case .connecting:
            ConnectingView()

        case .signedOut:
            SignedOutView(onConnect: { showingConnect = true })
                .transition(.opacity)

        case .ready:
            library
        }
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

/// The one screen in Sortify that legitimately occupies the user while nothing
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

    var body: some View {
        VStack(spacing: 22) {
            SortifyMarkTile(side: 84)
                // The mark arrives rather than appearing: a small settle, once,
                // that reads as the app assembling itself. Reduced Motion gets
                // the same screen without it, because this carries no meaning
                // that motion is required to convey.
                .scaleEffect(settled || reduceMotion ? 1 : 0.92)
                .opacity(settled || reduceMotion ? 1 : 0)

            VStack(spacing: 10) {
                Text("Connecting to Spotify")
                    .font(.headline)
                ProgressView()
                    .controlSize(.small)
            }
            .opacity(settled || reduceMotion ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SortifyTheme.background)
        .task {
            guard !reduceMotion else { return }
            withAnimation(.snappy(duration: 0.45)) { settled = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connecting to Spotify")
    }
}
