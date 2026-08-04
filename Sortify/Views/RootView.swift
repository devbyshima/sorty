import SwiftUI

struct RootView: View {
    @Environment(SessionModel.self) private var session
    @State private var path: [Playlist] = []
    @State private var showingSettings = false
    @State private var showingFAQ = false
    @State private var didRestore = false

    var body: some View {
        Group {
            switch session.stage {
            case .signedOut, .failed:
                LandingView(
                    showingSettings: $showingSettings,
                    showingFAQ: $showingFAQ
                )

            case .connecting:
                ConnectingView()

            case .signedIn:
                NavigationStack(path: $path) {
                    PlaylistsView(onSelect: { path.append($0) })
                        .navigationDestination(for: Playlist.self) { playlist in
                            TrackTableView(model: session.makeTrackTableModel(for: playlist))
                        }
                        .toolbar { navigationToolbar }
                }
            }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingFAQ) { FAQView() }
        .task {
            guard !didRestore else { return }
            didRestore = true
            await session.restore()
            await applyDebugLaunchIfNeeded()
        }
    }

    /// Drives the app to a named screen on launch so each one can be captured
    /// headlessly. No-op in release builds.
    private func applyDebugLaunchIfNeeded() async {
        guard let screen = DebugLaunch.screen else { return }
        switch screen {
        case .landing:
            await session.signOut()
        case .playlists:
            break
        case .faq:
            showingFAQ = true
        case .settings:
            showingSettings = true
        case .tracks:
            let target = DebugLaunch.playlistID.flatMap { id in
                session.playlists.first { $0.id == id }
            } ?? session.playlists.first
            if let target { path = [target] }
        }
    }

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section(session.user?.displayName ?? session.user?.id ?? "Signed in") {
                    Label(session.configuration.serviceMode.label, systemImage: "dot.radiowaves.left.and.right")
                }
                Button("Settings", systemImage: "gearshape") { showingSettings = true }
                Button("FAQ", systemImage: "questionmark.circle") { showingFAQ = true }
                Divider()
                Button(
                    session.configuration.serviceMode == .demo ? "Leave Demo Mode" : "Sign Out",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    role: .destructive
                ) {
                    Task { await session.signOut() }
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
