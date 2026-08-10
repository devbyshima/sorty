import SwiftUI

/// Who Sorty is a port of.
///
/// **Its own destination, one tap from Settings.** The credit used to be a
/// three-line `Section` at the foot of the FAQ - below fourteen collapsed
/// questions, inside a sheet opened from another sheet - which is a credit
/// nobody would ever reach. Sorty exists because Paul Lamere built Sort Your
/// Music; that is a fact about the app worth a screen rather than a footnote.
///
/// Links open with `openURL`, **not** `InAppBrowser`. That is an
/// `ASWebAuthenticationSession`, chosen so the Spotify dashboard shares Safari's
/// cookie jar, and pointing one at GitHub raises a system alert reading "Sorty
/// wants to use github.com to sign in" - which is both alarming and untrue.
struct CreditsView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        SettingsScaffold(title: CreditsText.title) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(CreditsText.origin)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, SettingsMetrics.rowVertical)
            }

            SettingsCard {
                linkRow(icon: "person", title: CreditsText.paulLamereLink, url: CreditsText.paulLamereURL)
                linkRow(icon: "chevron.left.forwardslash.chevron.right",
                        title: CreditsText.sortYourMusicLink,
                        url: CreditsText.sortYourMusicURL)
                linkRow(icon: "app.dashed", title: CreditsText.sortyLink, url: CreditsText.sortyURL)
            }

            SettingsExplainer(CreditsText.notAffiliated)
        }
    }

    private func linkRow(icon: String, title: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            SettingsRowLabel(icon: icon, title: title) {
                SettingsExternalIcon()
            }
        }
        .buttonStyle(.settingsRow)
        .accessibilityHint("Opens \(url.host() ?? "a web page")")
    }
}
