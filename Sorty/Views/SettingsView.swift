import SwiftUI

struct SettingsView: View {
    @Environment(SessionModel.self) private var session
    @Environment(\.dismiss) private var dismiss
    /// The dashboard, when it is open.
    @State private var browsing: BrowsableURL?
    /// The same key `RootView` applies, so changing it here changes the whole
    /// app rather than this sheet.
    @AppStorage("appearance") private var appearance: AppearanceChoice = .system
    @State private var showingFAQ = false

    var body: some View {
        @Bindable var session = session

        NavigationStack {
            Form {
                // Moved out of the library's menu, which was listing status
                // among a set of actions. Both belong beside the control that
                // changes them, which is the picker directly below.
                Section {
                    LabeledContent("Account", value: session.user?.displayName ?? session.user?.id ?? "Not connected")
                } header: {
                    Text("Account")
                }

                Section {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppearanceChoice.allCases) { choice in
                            Text(choice.label).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Light and dark are both designed. System follows whatever your device is set to.")
                }

                if session.isConnected {
                    // Not decoration: "collaborative playlists don't show up"
                    // has three different causes that look identical from the
                    // library - a token granted before Sorty asked for the
                    // permission, a reconnect that silently didn't take, and
                    // playlists that are shared but not actually collaborative.
                    // These two rows separate them.
                    Section {
                        LabeledContent("Reads collaborative") {
                            Text(session.grantedScopes.contains("playlist-read-collaborative") ? "Yes" : "No")
                                .foregroundStyle(
                                    session.grantedScopes.contains("playlist-read-collaborative")
                                        ? AnyShapeStyle(.secondary)
                                        : AnyShapeStyle(SortyTheme.accent)
                                )
                        }
                        LabeledContent("Collaborative playlists", value: "\(session.collaborativeCount)")
                    } header: {
                        Text("Spotify access")
                    } footer: {
                        Text(session.grantedScopes.contains("playlist-read-collaborative")
                             ? "Spotify only marks a playlist collaborative when other people can add and remove tracks. Sharing a link does not make one collaborative."
                             : "This account connected before Sorty asked for permission to read collaborative playlists. Sign out and connect again to grant it.")
                    }

                    Section {
                        LabeledContent("Client ID") {
                            TextField("Paste from the Spotify dashboard", text: $session.configuration.clientID)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Redirect URI") {
                            TextField(AppConfiguration.defaultRedirectURI, text: $session.configuration.redirectURI)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .multilineTextAlignment(.trailing)
                        }
                        // Same in-app browser the connect flow uses: this row
                        // sits directly above the Client ID field it feeds, and
                        // sending somebody to Safari to fetch a string for a
                        // field they are looking at is the errand `InAppBrowser`
                        // exists to remove.
                        Button {
                            browsing = SpotifyLinks.dashboard
                        } label: {
                            Label {
                                Text("Open Spotify Developer Dashboard")
                            } icon: {
                                Image(systemName: "arrow.up.right")
                            }
                        }
                    } header: {
                        Text("Spotify app")
                    } footer: {
                        Text("""
                            Create an app on the Spotify dashboard, then paste its Client ID here. \
                            Register the redirect URI **exactly** as it appears above, and add your \
                            own Spotify account under Users Management.

                            Two limits worth knowing before you start: a development-mode app admits \
                            at most five listeners and its owner needs Spotify Premium. Spotify's own \
                            docs prefer an https redirect over a custom scheme. If the dashboard \
                            rejects `sorty://callback` as insecure, point this at an https URL you \
                            control instead.
                            """)
                    }

                    Section {
                        Picker("Provider", selection: $session.configuration.featureSource) {
                            ForEach(FeatureSourceMode.allCases, id: \.self) { source in
                                Text(source.label).tag(source)
                            }
                        }
                    } header: {
                        Text("Audio features")
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(session.configuration.featureSource.explanation)
                            if session.configuration.featureSource.sendsTrackIDsOffDevice {
                                Label(
                                    "Track IDs for the playlist you open are sent to api.reccobeats.com. Nothing else leaves the device: not your name, not your tokens.",
                                    systemImage: "hand.raised"
                                )
                                .font(.caption)
                            }
                        }
                    }
                }

                Section {
                    Text("""
                        BPM, Energy, Dance, Loud, Valence and Acoustic come from an audio-feature \
                        source. Spotify restricted its own audio-features endpoint in November 2024 \
                        for every app registered after that date and has published no replacement, \
                        so Sorty defaults to ReccoBeats. The other nine columns come straight from \
                        Spotify and always work.
                        """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Why this setting exists")
                }

                Section {
                    Button("Frequently asked questions", systemImage: "questionmark.circle") {
                        showingFAQ = true
                    }
                }
            }
            .sheet(isPresented: $showingFAQ) { FAQView() }
            .sheet(item: $browsing) { target in
                InAppBrowser(url: target.url)
                    .ignoresSafeArea()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
    }
}
