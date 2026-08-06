import SwiftUI

/// Connecting a Spotify account, as a guided sequence rather than a card
/// pointing at Settings.
///
/// It is reached from Save — the one thing Demo Mode cannot do — so the Client
/// ID requirement arrives attached to a motive the listener already has, rather
/// than as an upfront toll (ADR-0003). Every word is `ConnectStep` in
/// SortifyKit; this file moves between steps and collects two strings.
struct ConnectFlowView: View {
    @Environment(SessionModel.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var step: ConnectStep = .why
    @State private var clientID = ""
    @State private var isAuthenticating = false
    @State private var presenter = AuthPresenter()

    private var check: ClientIDCheck { ClientIDCheck.check(clientID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(step.position)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SortifyTheme.accent)

                    Text(step.title)
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    Text(step.body)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    stepControls

                    if let failure = session.connectFailure {
                        ErrorRow(message: failure)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(SortifyTheme.background)
            .safeAreaInset(edge: .bottom) { advanceBar }
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let previous = step.previous {
                        Button("Back") { step = previous }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Not Now") { dismiss() }
                }
            }
            .onAppear {
                clientID = session.configuration.clientID
                if let start = DebugLaunch.connectStep { step = start }
            }
        }
    }

    // MARK: - Per-step controls

    @ViewBuilder
    private var stepControls: some View {
        switch step {
        case .why:
            EmptyView()

        case .createApp:
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    if let url = URL(string: "https://developer.spotify.com/dashboard") {
                        openURL(url)
                    }
                } label: {
                    Label("Open the Spotify Dashboard", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(SortifyTheme.spotifyGreen)
                .controlSize(.large)

                redirectURI
            }

        case .clientID:
            VStack(alignment: .leading, spacing: 8) {
                TextField("Client ID", text: $clientID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .font(.body.monospaced())
                    .padding(12)
                    .background(SortifyTheme.surface, in: .rect(cornerRadius: 10))

                // Named as soon as it's visible, rather than at the far end of
                // a web sheet as Spotify's own INVALID_CLIENT.
                if let problem = check.problem, !clientID.isEmpty {
                    Label(problem, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

        case .authorize:
            EmptyView()
        }
    }

    /// Given rather than described, because a redirect URI that is subtly wrong
    /// fails at authorisation with a message about the *app* rather than about
    /// the one character that differs.
    private var redirectURI: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Redirect URI")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack {
                Text(session.configuration.redirectURI)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Button {
                    UIPasteboard.general.string = session.configuration.redirectURI
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .foregroundStyle(SortifyTheme.accent)
                .accessibilityLabel("Copy redirect URI")
            }
            .padding(12)
            .background(SortifyTheme.surface, in: .rect(cornerRadius: 10))
        }
    }

    // MARK: - Advancing

    private var advanceBar: some View {
        Button {
            advance()
        } label: {
            if isAuthenticating {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text(step.advanceTitle).frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.glassProminent)
        .tint(step == .authorize ? SortifyTheme.spotifyGreen : SortifyTheme.accent)
        .controlSize(.large)
        .disabled(!canAdvance)
        .padding(20)
        .background(.bar)
    }

    private var canAdvance: Bool {
        guard !isAuthenticating else { return false }
        // The only step with something to get wrong.
        return step != .clientID || check.isValid
    }

    private func advance() {
        if step == .clientID {
            session.configuration.clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard step == .authorize else {
            step = step.next ?? step
            return
        }
        Task { await connect() }
    }

    /// The authorisation is also the verification: nothing tells the listener
    /// setup worked until Spotify has answered and `currentUser()` has come
    /// back with a name.
    private func connect() async {
        isAuthenticating = true
        defer { isAuthenticating = false }

        session.beginConnecting()
        session.configuration.serviceMode = .spotify

        guard let url = await session.authorizationURL() else {
            await session.signInFailed(SpotifyAuthError.notConfigured)
            return
        }

        do {
            let callback = try await presenter.authenticate(
                url: url, redirectURI: session.configuration.authConfig.redirectURI
            )
            await session.handleAuthCallback(url: callback)
            if session.connectFailure == nil, !session.isDemo {
                dismiss()
            }
        } catch {
            await session.signInFailed(error)
        }
    }
}
