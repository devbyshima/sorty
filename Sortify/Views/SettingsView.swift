import SwiftUI

struct SettingsView: View {
    @Environment(SessionModel.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var session = session

        NavigationStack {
            Form {
                Section {
                    Picker("Backend", selection: $session.configuration.serviceMode) {
                        ForEach(ServiceMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                } header: {
                    Text("Source")
                } footer: {
                    Text(session.configuration.serviceMode == .demo
                         ? "Demo Mode serves a built-in sample catalogue. Every column is populated and every sort works, but nothing can be saved back."
                         : "Sortify talks to your Spotify account with your own Client ID.")
                }

                if session.configuration.serviceMode == .spotify {
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
                        Button("Open Spotify Developer Dashboard", systemImage: "safari") {
                            if let url = URL(string: "https://developer.spotify.com/dashboard") {
                                openURL(url)
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
                            docs prefer an https redirect over a custom scheme — if the dashboard \
                            rejects `sortify://callback` as insecure, point this at an https URL you \
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
                                    "Track IDs for the playlist you open are sent to api.reccobeats.com. Nothing else leaves the device — not your name, not your tokens.",
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
                        so Sortify defaults to ReccoBeats. The other nine columns come straight from \
                        Spotify and always work.
                        """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Why this setting exists")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}
