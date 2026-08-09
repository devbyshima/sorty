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
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: ConnectStep = .why
    @State private var clientID = ""
    @State private var isAuthenticating = false
    @State private var presenter = AuthPresenter()

    private var check: ClientIDCheck { ClientIDCheck.check(clientID) }

    var body: some View {
        NavigationStack {
            // The page fills the space it has been given, rather than stacking
            // from the top and leaving a void above the button.
            //
            // As a card this read fine, because a sheet is only as tall as its
            // content. A full-screen page is not: step 1 is a heading and two
            // short paragraphs, and top-aligned on a 6.3" display that left a
            // hand's depth of nothing between the last line and Continue, which
            // looks like a screen that failed to finish loading.
            //
            // `minHeight` rather than a plain centre, so the two steps that
            // *do* overflow - the Client ID field with a keyboard up, and the
            // dashboard step - still scroll instead of being squeezed.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 28)

                        // The glyph, the words and the controls travel as one
                        // page. Only the two `Text`s used to carry the
                        // transition, so a step change slid the heading sideways
                        // while the symbol above it and the field below it were
                        // replaced in place - a screen rearranging itself rather
                        // than one page leaving and the next arriving.
                        VStack(spacing: 24) {
                            VStack(spacing: 24) {
                                stepGlyph

                                VStack(spacing: 12) {
                                    Text(step.title)
                                        .font(.title2.bold())
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text(step.body)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .id(step)
                            .transition(.page(reduceMotion: reduceMotion))

                            // Same travel, same fade, same timing - and no
                            // shader. The Client ID field is UIKit-backed and
                            // cannot survive the offscreen pass a `layerEffect`
                            // forces; see `PageTransition.smears`.
                            stepControls
                                .id(step)
                                .transition(.page(reduceMotion: reduceMotion, smears: false))
                        }

                        Spacer(minLength: 28)

                        // Outside the page and holding still while pages move: a
                        // failure belongs to the attempt rather than to the step
                        // it happened on, and sliding it away would take the
                        // explanation with it.
                        if let failure = session.connectFailure {
                            ErrorRow(message: failure)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    // No band to clear any more: the spine is pinned above this
                    // and carries the blur itself, so the page starts directly
                    // under it.
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    .frame(minHeight: proxy.size.height)
                }
            }
            // See SignedOutView: a background, not a sibling, or the circle
            // sizes the stack and the text runs off both edges.
            .background { SplashBackdrop() }
            // For content that scrolls under the toolbar. The dots do not need
            // clearing from it - they are toolbar content, which draws above
            // this - and the page is centred rather than top-aligned, so at rest
            // nothing sits in the band at all.
            .overlay(alignment: .top) { TopBlur(height: 44, overscan: 0) }
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { advanceBar }
            // No navigation title. Beam's onboarding screens carry none, and the
            // spine plus the step's own heading already say both what this is
            // and how much of it is left - "Connect Spotify" above "Sorty needs
            // your own Spotify app" was the same sentence twice.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // One button, and it is a back button all the way down.
                //
                // There was an X beside it for leaving. Once the flow pushes in
                // from the right rather than rising from the bottom, that second
                // affordance stops making sense: pages that push have one way
                // back, and going back off the first page is how you leave. So
                // the chevron pops a step until there are none, then closes.
                //
                // The flow is still leavable at every step, which ADR-0007
                // requires - a way in nobody can escape is a worse first
                // impression than the way-in screen. It just takes the number of
                // taps the depth implies, instead of one.
                ToolbarItem(placement: .principal) { stepDots }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let previous = step.previous {
                            withAnimation(.snappy(duration: 0.25)) { step = previous }
                        } else {
                            onClose()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    // The word is gone from the screen and kept here. A bare
                    // glyph with no accessible name is a button that announces
                    // itself as "button".
                    .accessibilityLabel(step.previous == nil ? "Close" : "Back")
                }
            }
            .onAppear {
                clientID = session.configuration.clientID
                if let start = DebugLaunch.connectStep { step = start }
            }
            #if DEBUG
            // `-advanceAfter N`: drives one step change so the transition can be
            // photographed. No-op in a shipping build.
            //
            // **Deliberately slower than the real thing.** A tap animates over
            // 0.25s and `simctl io screenshot` takes about 0.25s to return, so a
            // burst straddles the whole transition and lands on either side of
            // it - measured, twice. What is being verified here is that
            // `pageSmear` resolves and draws at all, which the duration has no
            // bearing on; stretching it is the difference between a photograph
            // and a guess.
            .task {
                guard let delay = DebugLaunch.advanceAfter, let next = step.next else { return }
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(.easeInOut(duration: 1.6)) { step = next }
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

    /// One symbol per step, in the accent, above the heading.
    ///
    /// Beam opens every onboarding screen with a mark or a glyph and puts the
    /// words underneath it, and the four steps here were a wall of left-aligned
    /// prose. The symbol is the cheapest way to make four screens tell
    /// themselves apart before any of them is read.
    ///
    /// **No pulse rings.** Beam puts them on the screen that is *searching* -
    /// it is actively scanning the network and the rings say so. Sorty's last
    /// step is not searching: it is a button waiting for a finger, and rings
    /// behind it would claim the app is working when it is idle. The one moment
    /// this screen genuinely waits is after the tap, and the advance button
    /// already carries a spinner for exactly that.
    private var stepGlyph: some View {
        Image(systemName: symbol(for: step))
            .font(.system(size: 44, weight: .medium))
            .foregroundStyle(SortyTheme.accent.gradient)
            .contentTransition(.symbolEffect(.replace.downUp))
            .frame(height: 72)
            .accessibilityHidden(true)
    }

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
