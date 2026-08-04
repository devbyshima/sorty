import SwiftUI

struct LandingView: View {
    @Environment(SessionModel.self) private var session
    @Binding var showingSettings: Bool
    @Binding var showingFAQ: Bool

    @State private var presenter = AuthPresenter()
    @State private var isAuthenticating = false

    private var failureMessage: String? {
        if case .failed(let message) = session.stage { return message }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 40)

                VStack(spacing: 14) {
                    Image(systemName: "arrow.up.arrow.down.square.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(SortifyTheme.accent)
                        .accessibilityHidden(true)

                    Text("Sortify")
                        .font(.largeTitle.bold())

                    Text("Sort your playlists by tempo, energy, danceability, loudness, valence and more — then save the new order back.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                }

                if let failureMessage {
                    Label(failureMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.red.opacity(0.1), in: .rect(cornerRadius: 12))
                }

                VStack(spacing: 12) {
                    Button {
                        Task { await signInWithSpotify() }
                    } label: {
                        Label("Connect Spotify", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(isAuthenticating)

                    Button {
                        Task { await session.enterDemo() }
                    } label: {
                        Label("Explore Demo Mode", systemImage: "play.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .disabled(isAuthenticating)
                }
                .padding(.horizontal, 4)

                if !session.configuration.hasSpotifyCredentials {
                    Label {
                        Text("Connecting needs your own Spotify **Client ID** — Spotify caps each app at five listeners, so a shared one would lock everybody else out. Add it in Settings.")
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(SortifyTheme.surface, in: .rect(cornerRadius: 14))
                }

                HStack(spacing: 18) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                    Button("FAQ", systemImage: "questionmark.circle") { showingFAQ = true }
                }
                .font(.footnote)
                .buttonStyle(.plain)
                .foregroundStyle(SortifyTheme.accent)

                Text("Demo Mode uses a built-in sample catalogue — no account, no network.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 24)
            }
            .frame(maxWidth: 460)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .background(SortifyTheme.background)
    }

    private func signInWithSpotify() async {
        guard session.configuration.hasSpotifyCredentials else {
            showingSettings = true
            return
        }
        guard let url = await session.authorizationURL() else {
            showingSettings = true
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let callback = try await presenter.authenticate(
                url: url,
                redirectURI: session.configuration.authConfig.redirectURI
            )
            await session.handleAuthCallback(url: callback)
        } catch {
            session.signInFailed(error)
        }
    }
}
