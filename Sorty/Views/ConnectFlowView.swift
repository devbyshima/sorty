import SwiftUI

/// Connecting a Spotify account, as a guided sequence rather than a card
/// pointing at Settings.
///
/// It is reached from the way-in screen and from Save, so the Client
/// ID requirement arrives attached to a motive the listener already has, rather
/// than as an upfront toll (ADR-0003). Every word is `ConnectStep` in
/// SortyKit; this file moves between steps and collects two strings.
///
/// The presentation is the onboarding: a visible spine of four steps so nobody
/// is asked to trust an unknown number of screens, one instruction per screen,
/// and a bottom bar that never moves. The words themselves were already right;
/// what they lacked was somewhere to stand.
struct ConnectFlowView: View {
    @Environment(SessionModel.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: ConnectStep = .why
    @State private var clientID = ""
    @State private var isAuthenticating = false
    @State private var presenter = AuthPresenter()

    private var check: ClientIDCheck { ClientIDCheck.check(clientID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    stepSpine

                    VStack(alignment: .leading, spacing: 12) {
                        Text(step.title)
                            .font(.title2.bold())
                            .fixedSize(horizontal: false, vertical: true)

                        Text(step.body)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Content slides in the direction of travel, so a step
                    // forward and a step back are distinguishable without
                    // reading anything.
                    .id(step)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                    )

                    stepControls

                    if let failure = session.connectFailure {
                        ErrorRow(message: failure)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(SortyTheme.background)
            // Short tail: the step track sits close under the bar, and a long
            // fade smeared it and "Step 3 of 4" on a screen that never scrolls.
            .overlay(alignment: .top) { TopBlur(height: 44, overscan: 0) }
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { advanceBar }
            .navigationTitle("Connect Spotify")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let previous = step.previous {
                        Button("Back") {
                            withAnimation(.snappy(duration: 0.25)) { step = previous }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Still leavable at every step, even though connecting is
                    // now the only way in (ADR-0007). A modal nobody can escape
                    // is a worse first impression than the way-in screen, which
                    // at least names its own remedy and can be returned to.
                    Button("Not Now") { dismiss() }
                }
            }
            .onAppear {
                clientID = session.configuration.clientID
                if let start = DebugLaunch.connectStep { step = start }
            }
        }
    }

    // MARK: - Spine

    /// Four segments, filled up to where you are.
    ///
    /// The old flow said "Step 2 of 4" in small type. A spine says the same
    /// thing without being read, and - the part that matters - shows the
    /// *shape* of what is being asked before any of it is asked, which is the
    /// difference between a short errand and an unknown number of screens.
    private var stepSpine: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(ConnectStep.allCases) { each in
                    Capsule()
                        .fill(each <= step ? AnyShapeStyle(SortyTheme.accent) : AnyShapeStyle(SortyTheme.raisedSurface))
                        .frame(height: 4)
                }
            }
            Text(step.position)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(step.position)
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
                .tint(SortyTheme.spotifyGreen)
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
                    .background(SortyTheme.surface, in: .rect(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                clientID.isEmpty
                                    ? SortyTheme.hairline
                                    : (check.isValid ? SortyTheme.accent : .orange),
                                lineWidth: 1
                            )
                    }

                // Named as soon as it's visible, rather than at the far end of
                // a web sheet as Spotify's own INVALID_CLIENT.
                if let problem = check.problem, !clientID.isEmpty {
                    Label(problem, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if check.isValid {
                    Label("That looks like a Client ID. Signing in is what proves it.", systemImage: "checkmark.circle")
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
                .foregroundStyle(SortyTheme.accent)
                .accessibilityLabel("Copy redirect URI")
            }
            .padding(12)
            .background(SortyTheme.surface, in: .rect(cornerRadius: 10))
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
        .tint(step == .authorize ? SortyTheme.spotifyGreen : SortyTheme.accent)
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
            withAnimation(.snappy(duration: 0.25)) { step = step.next ?? step }
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

        guard let url = await session.authorizationURL() else {
            await session.signInFailed(SpotifyAuthError.notConfigured)
            return
        }

        do {
            let callback = try await presenter.authenticate(
                url: url, redirectURI: session.configuration.authConfig.redirectURI
            )
            await session.handleAuthCallback(url: callback)
            if session.connectFailure == nil, session.isConnected {
                dismiss()
            }
        } catch {
            await session.signInFailed(error)
        }
    }
}
