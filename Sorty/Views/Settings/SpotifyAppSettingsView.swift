import SwiftUI

/// The Client ID and the redirect URI, and how to get one.
///
/// **The fields commit on submit, not on every keystroke, and that is a fix
/// rather than a style.** These used to bind straight to
/// `session.configuration`, whose `didSet` saves to `UserDefaults` and calls
/// `rebuildServices()` - so typing a 32-character Client ID tore down and
/// rebuilt the authenticator, the music service and the feature provider
/// thirty-two times, once per character, each time against a prefix of an ID
/// that was not yet valid.
struct SpotifyAppSettingsView: View {
    @Environment(SessionModel.self) private var session

    /// The dashboard. Opened on the same cookies the sign-in reads, so it does
    /// not ask for a login the listener has already given.
    @State private var browser = InAppBrowser()

    /// Drafts. Seeded on appear and written back on submit or on leaving, which
    /// are the two moments a listener has finished typing.
    @State private var clientID = ""
    @State private var redirectURI = ""

    var body: some View {
        SettingsScaffold(title: SettingsText.spotifyApp) {
            SettingsCard {
                credentialRow(
                    title: SettingsText.clientID,
                    prompt: SettingsText.clientIDPrompt,
                    text: $clientID
                )
                credentialRow(
                    title: SettingsText.redirectURI,
                    prompt: AppConfiguration.defaultRedirectURI,
                    text: $redirectURI
                )
                // Directly under the field it feeds. Sending somebody to Safari
                // to fetch a string for a field they are looking at is the
                // errand `InAppBrowser` exists to remove.
                Button {
                    commit()
                    browser.open(SpotifyLinks.dashboard)
                } label: {
                    SettingsRowLabel(icon: "arrow.up.forward.square", title: SettingsText.openDashboard) {
                        SettingsExternalIcon()
                    }
                }
                .buttonStyle(.settingsRow)
            }

            SettingsExplainer(SettingsText.spotifyAppSetup)
            SettingsExplainer(SettingsText.spotifyAppLimits)
        }
        .onAppear {
            clientID = session.configuration.clientID
            redirectURI = session.configuration.redirectURI
        }
        // Leaving is a submission too: a listener who pastes an ID and swipes
        // back has finished typing just as surely as one who taps Return, and
        // silently discarding it would be the worst reading of the gesture.
        .onDisappear(perform: commit)
    }

    /// Label above field rather than beside it.
    ///
    /// A `LabeledContent` with a trailing `TextField` gives a 32-character
    /// opaque string about half a row, right-aligned, truncated from the middle
    /// - which is unreadable exactly when it matters, and impossible to check
    /// against the dashboard character for character the way the note below
    /// asks. Stacked, the value gets the full width.
    private func credentialRow(
        title: String,
        prompt: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .font(.body.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(commit)
        }
        .padding(.vertical, SettingsMetrics.twoLineRowVertical)
    }

    /// One write, through the helpers that hold the two rules worth keeping:
    /// a stored Client ID is trimmed, and an emptied redirect URI restores the
    /// default rather than silently unconfiguring the app.
    private func commit() {
        let updated = session.configuration
            .settingClientID(clientID)
            .settingRedirectURI(redirectURI)
        guard updated != session.configuration else { return }
        session.configuration = updated
        // Reflect back whatever the rules made of it, so the field shows the
        // string that was actually stored rather than the one that was typed.
        clientID = updated.clientID
        redirectURI = updated.redirectURI
    }
}
