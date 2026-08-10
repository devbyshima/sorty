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
    /// Leaving. Handed in rather than taken from the environment because this
    /// is pushed in as an overlay, not presented - so there is no `dismiss` to
    /// call and the animation out has to match the one in.
    var onClose: () -> Void = {}

    @Environment(SessionModel.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: ConnectStep = .why
    @State private var clientID = ""
    @State private var isAuthenticating = false
    @State private var presenter = AuthPresenter()
    @State private var showingDetail = false
    /// The dashboard, when it is open. Setup never leaves the app.
    @State private var browsing: BrowsableURL?

    private var check: ClientIDCheck { ClientIDCheck.check(clientID) }

    var body: some View {
        NavigationStack {
            // Beam's onboarding shape, and the way-in screen's: the glyph leads,
            // the words sit under it, the action is at the foot. The four steps
            // are the same screen as the reel with different words in it, which
            // is what makes the flow read as one thing rather than a landing
            // page followed by a form.
            OnboardingPage(
                symbol: symbol(for: step),
                title: step.title,
                text: step.body,
                onInfo: { showingDetail = true },
                glyphTop: OnboardingMetrics.flowGlyphTop
            ) {
                VStack(spacing: 14) {
                    stepControls

                    // Outside the page's own block and holding still while pages
                    // move: a failure belongs to the attempt rather than to the
                    // step it happened on, and sliding it away with the page
                    // would take the explanation with it.
                    if let failure = session.connectFailure {
                        ErrorRow(message: failure)
                    }
                }
                .padding(.top, 4)
            }
            .id(step)
            .transition(.onboardingPage(reduceMotion: reduceMotion))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { SplashBackdrop() }
            .safeAreaInset(edge: .bottom) { advanceBar }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { stepDots }
                // One button, and it is a back button all the way down: it pops
                // a step until there are none, then leaves. Pages that push have
                // one way back, so the X that a rising modal needed is gone.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let previous = step.previous {
                            withAnimation(.snappy(duration: 0.3)) { step = previous }
                        } else {
                            onClose()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel(step.previous == nil ? "Close" : "Back")
                }
            }
            .sheet(isPresented: $showingDetail) {
                ConnectDetailSheet(step: step)
            }
            // In a sheet over the flow rather than a hand-off to Safari. The
            // Client ID has to be carried from that page to the field on the
            // next one, and an errand across three apps is where it gets
            // dropped.
            .sheet(item: $browsing) { target in
                InAppBrowser(url: target.url)
                    .ignoresSafeArea()
            }
            .onAppear {
                clientID = session.configuration.clientID
                if let start = DebugLaunch.connectStep { step = start }
            }
            #if DEBUG
            .task {
                guard let delay = DebugLaunch.advanceAfter, let next = step.next else { return }
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(.snappy(duration: 0.3)) { step = next }
            }
            #endif
        }
    }

    // MARK: - Progress

    /// Four dots, filled up to where you are, level with the back button.
    ///
    /// It was a row of four capsules stretched across the width, under the
    /// chevron. That drew a *bar*, and a bar reads as a measure of how much work
    /// is left - which four short screens do not need and which made the flow
    /// look longer than it is. Dots say the same thing in the space between two
    /// toolbar buttons: four things, this many done.
    ///
    /// In the toolbar rather than under it, which is what puts it level with the
    /// chevron and also solves the blur problem the old spine had. Toolbar
    /// content draws above the scroll view's overlay, so the dots stay sharp
    /// with no padding pushing anything down (ADR-0016).
    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(ConnectStep.allCases) { each in
                Circle()
                    .fill(each <= step ? AnyShapeStyle(SortyTheme.accent) : AnyShapeStyle(SortyTheme.raisedSurface))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(step.position)
    }

    // MARK: - The step's glyph

    /// Presentation, so it lives here rather than on `ConnectStep`. SortyKit
    /// holds the words because the words are the flow; an SF Symbol name is a
    /// fact about this app's interface and nothing else.
    private func symbol(for step: ConnectStep) -> String {
        switch step {
        case .why: "person.badge.key"
        case .createApp: "hammer"
        case .clientID: "document.on.clipboard"
        case .authorize: "checkmark.shield"
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
                    browsing = SpotifyLinks.dashboard
                } label: {
                    HStack(spacing: 6) {
                        Text("Open the Spotify Dashboard")
                        // The same box as this app's own save glyph
                        // (`square.and.arrow.down` on the way-in screen),
                        // inverted so the arrow leaves rather than enters, and
                        // turned diagonal. A bare `arrow.up.right` was a
                        // direction; this is a thing being opened out of, which
                        // is what a link is - and it rhymes with a symbol the
                        // listener has already met one screen earlier.
                        Image(systemName: "arrow.up.forward.square")
                            .font(.footnote.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                // Spotify's green, in glass. Prominent rather than plain,
                // because on this step it is the thing to do - the advance
                // button below only becomes true once this has been.
                .buttonStyle(.glassProminent)
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
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        // No bar behind it. `safeAreaInset` already reserves the space, so
        // nothing scrolls under the button, and a grey slab here would cut the
        // bloom in half exactly where it is brightest.
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
                onClose()
            }
        } catch {
            await session.signInFailed(error)
        }
    }
}

/// The longer answer to a step, opened from the info button beside its words.
///
/// A sheet rather than another page: it is an aside, not a stop on the way, and
/// it has to be leavable without losing your place in a four-step sequence.
struct ConnectDetailSheet: View {
    let step: ConnectStep

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(step.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(SortyTheme.background)
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Done")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
