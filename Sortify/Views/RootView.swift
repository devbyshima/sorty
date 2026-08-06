import SwiftUI

/// The app, which is always in a session.
///
/// There is no signed-out screen. ADR-0003 makes Demo Mode the front door, so a
/// first-run listener is arranging a real-looking playlist within seconds
/// instead of meeting the highest-friction moment in the product before any
/// demonstration of its value. Connecting is reached from Save — the one thing
/// Demo Mode cannot do — and from the account menu.
struct RootView: View {
    @Environment(SessionModel.self) private var session
    @State private var path: [Playlist] = []
    @State private var showingSettings = false
    @State private var showingFAQ = false
    @State private var showingConnect = false
    @State private var didRestore = false

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

        case .ready:
            NavigationStack(path: $path) {
                PlaylistsView(onSelect: { path.append($0) })
                    .navigationDestination(for: Playlist.self) { playlist in
                        TrackListView(
                            model: session.makeTrackListModel(for: playlist),
                            onConnect: { showingConnect = true }
                        )
                    }
                    .toolbar { navigationToolbar }
            }
        }
    }

    /// Drives the app to a named screen on launch so each one can be captured
    /// headlessly. No-op in release builds.
    private func applyDebugLaunchIfNeeded() async {
        guard let screen = DebugLaunch.screen else { return }
        switch screen {
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

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section(session.user?.displayName ?? session.user?.id ?? "Demo Mode") {
                    Label(session.configuration.serviceMode.label, systemImage: "dot.radiowaves.left.and.right")
                }
                // The other way in, for someone who came to sort their own
                // playlists and doesn't want to be shown a demo first.
                if session.isDemo {
                    Button("Connect Spotify", systemImage: "link") { showingConnect = true }
                }
                Button("Settings", systemImage: "gearshape") { showingSettings = true }
                Button("FAQ", systemImage: "questionmark.circle") { showingFAQ = true }
                if !session.isDemo {
                    Divider()
                    Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        Task { await session.signOut() }
                    }
                }
            } label: {
                Label("Account", systemImage: "person.crop.circle")
            }
        }
    }
}

struct ConnectingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Connecting…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SortifyTheme.background)
    }
}
