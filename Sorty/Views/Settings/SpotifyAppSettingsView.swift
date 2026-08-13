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
            // **Two cards, where one card held three rows on two different left
            // edges.** The credential labels start at the card's content edge;
            // an icon row's title starts 40pt further in, because
            // `SettingsRowLabel` reserves a glyph column. Putting both in one
            // card gave it two competing left margins and a divider that agreed
            // with neither - which is most of what "messy" meant on this screen.
            // Splitting them also separates "type here" from "leave the app".
            SettingsCard(dividerInset: 0) {
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
            }

            SettingsCard {
                // Sending somebody to Safari to fetch a string for a field they
                // are looking at is the errand `InAppBrowser` exists to remove.
                //
                // `safari` rather than `arrow.up.forward.square`: the row already
                // ends in `SettingsExternalIcon`, which is that same arrow, so
                // the old pairing drew one glyph twice and said nothing about
                // where the row goes. Topical glyph leading, "it leaves" trailing
                // - the pattern `CreditsView` already uses.
                Button {
                    commit()
                    browser.open(SpotifyLinks.dashboard)
                } label: {
                    SettingsRowLabel(icon: "safari", title: SettingsText.openDashboard) {
                        SettingsExternalIcon()
                    }
                }
                .buttonStyle(.settingsRow)
            }

            // One note, not two. As separate explainers they sat `attachedGap`
            // apart - less than their own line height - so they read as one
            // block anyway, but with a gap in the wrong place. Joined, the blank
            // line is a real paragraph break.
            SettingsExplainer(SettingsText.spotifyAppSetup + "\n\n" + SettingsText.spotifyAppLimits)
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
        VStack(alignment: .leading, spacing: 6) {
            // `.footnote` weighted, not `.caption` regular. A field label sitting
            // at the same size and colour as the page footnote below made the top
            // of this card read as a paragraph rather than as the form it is.
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            // **The field is given a surface, because it had none.** No box, no
            // fill, no rule - on first run the Client ID row was a grey label
            // above grey placeholder text, so the one actionable thing on the
            // screen was the thing that looked least like a control.
            // `raisedSurface` is the existing token for one step above a card,
            // and it works in both Appearances without a second value.
            // **`.subheadline`, sized against the string it has to hold.** A
            // Spotify Client ID is thirty-two hex characters. At `.body`
            // monospaced the advance is about 10.2pt, so thirty-two of them need
            // 326pt against the 314pt this field actually has - the value this
            // whole stacked layout exists to show in full was truncating, and so
            // was its own prompt ("Paste from the Spotify dashboa…"). At 15pt the
            // advance is about 9.0pt and thirty-two characters take 288pt, which
            // fits with room for the caret.
            TextField(prompt, text: text)
                .font(.subheadline.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(commit)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(SortyTheme.raisedSurface, in: .rect(cornerRadius: 10))
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
