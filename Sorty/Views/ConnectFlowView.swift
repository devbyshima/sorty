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
    /// Whether the redirect URI is on the clipboard, which is what turns this
    /// step's one control from Copy into Open.
    ///
    /// Reset whenever the step changes, so coming back offers the copy again
    /// rather than stranding somebody whose clipboard has moved on.
    @State private var hasCopiedRedirectURI = false

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
                // As tall as it is, and never taller. Everything on a connect
                // step hangs off the bottom edge - the words above it are
                // pinned there, and a step's controls push them up by exactly
                // their own height - so anything here that could *grow*
                // competes with the page's own spacer for the leftover and
                // pulls the whole block off the bottom. That is what a
                // `Spacer` in this position did: it split the leftover with the
                // spacer above, and the words floated into the middle of the
                // screen instead of sitting over the button.
                VStack(spacing: 14) {
                    stepControls

                    // Outside the page's own block and holding still while
                    // pages move: a failure belongs to the attempt rather than
                    // to the step it happened on, and sliding it away with the
                    // page would take the explanation with it.
                    if let failure = session.connectFailure {
                        ErrorRow(message: failure)
                    }
                }
                // Both insets, or neither. The gap above the button lives here,
                // in the page, rather than in the bar under it: padding the bar
                // makes the *foot* deeper, and the foot's depth is what levels
                // these screens against the first page, so a step that took its
                // clearance from the bar bought it by lifting its own words off
                // that line.
                //
                // And an empty block still takes its padding. On the two steps
                // carrying nothing, 4 and 16 are 20pt of air under a view with
                // no height - which is 20pt of drift on exactly the two screens
                // that are supposed to match the first page to the pixel.
                .padding(.top, hasFoot ? 4 : 0)
                .padding(.bottom, hasFoot ? OnboardingMetrics.buttonClearance : 0)
            }
            .id(step)
            .transition(.onboardingPage(reduceMotion: reduceMotion))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { SplashBackdrop() }
            // `spacing: 0` is load-bearing. Left to itself `safeAreaInset`
            // puts a default gap between the page and the inset, and that gap
            // is foot depth by another name: it held the words 12pt above the
            // line the way-in screen puts them on, with the buttons already
            // levelled to the pixel and nothing in the code to point at.
            .safeAreaInset(edge: .bottom, spacing: 0) { advanceBar }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { stepDots }
                // One button, and it is a back button all the way down: it pops
                // a step until there are none, then leaves. Pages that push have
                // one way back, so the X that a rising modal needed is gone.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let previous = step.previous {
                            hasCopiedRedirectURI = false
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
                // The URI goes with the step that has to register it, and only
                // that step. Passed rather than reached for, so which step shows
                // a value is a fact you can read here.
                ConnectDetailSheet(
                    step: step,
                    redirectURI: step == .createApp ? session.configuration.redirectURI : nil
                )
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
                if DebugLaunch.showsConnectDetail { showingDetail = true }
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

    /// Whether this step puts anything between its words and the button.
    ///
    /// The two that don't are the two that line up with the way-in screen to
    /// the pixel, and the padding around the control block is switched off for
    /// them so they stay that way.
    private var hasControls: Bool {
        switch step {
        case .why, .authorize: false
        case .createApp, .clientID: true
        }
    }

    /// The same question, asked of what is actually on screen: a failure puts a
    /// row under the words on any step, including the two that carry no
    /// controls of their own.
    private var hasFoot: Bool { hasControls || session.connectFailure != nil }

    @ViewBuilder
    private var stepControls: some View {
        switch step {
        case .why:
            EmptyView()

        case .createApp:
            // One control, and it is a button. The redirect URI used to be
            // printed above it in a box, which made this the only step in the
            // flow carrying a slab of text under its words - it read as a form,
            // and it is not one. The value moved behind the ⓘ, where it can be
            // read and checked by the listener who wants to; everyone else
            // copies it without ever needing to look at it.
            dashboardAction

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

    /// Copy, then open - one control doing both, in the order they happen.
    ///
    /// They were two buttons stacked, and the listener had to work out that the
    /// top one comes first. Now the button *is* the next thing: it copies, and
    /// having copied, it becomes the way to the dashboard. Nothing is offered
    /// twice and there is no order to infer.
    ///
    /// The colour carries the same story - the app's accent while the work is
    /// still Sorty's, Spotify's green once the next thing is on their site.
    private var dashboardAction: some View {
        Button {
            if hasCopiedRedirectURI {
                browsing = SpotifyLinks.dashboard
            } else {
                UIPasteboard.general.string = session.configuration.redirectURI
                withAnimation(.snappy(duration: 0.28)) { hasCopiedRedirectURI = true }
            }
        } label: {
            HStack(spacing: 6) {
                Text(hasCopiedRedirectURI ? "Open the Spotify Dashboard" : "Copy the redirect URI")
                    .contentTransition(.opacity)

                // The same box as this app's own save glyph, inverted so the
                // arrow leaves rather than enters, and turned diagonal: a thing
                // being opened out of, which is what a link is.
                Image(systemName: hasCopiedRedirectURI ? "arrow.up.forward.square" : "doc.on.doc")
                    .font(.footnote.weight(.semibold))
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        // The way-in screen's button, as every button in this flow now is. The
        // tint is the only thing that differs, and it is carrying the same
        // story as the words: the app's accent while the work is still Sorty's,
        // Spotify's green once the next thing is on their site.
        .buttonStyle(OnboardingButton(tint: hasCopiedRedirectURI ? SortyTheme.spotifyGreen : SortyTheme.accent))
        .accessibilityHint(
            hasCopiedRedirectURI
                ? "Opens Spotify's developer dashboard."
                : "Copies the redirect URI, then offers the dashboard."
        )
    }

    // MARK: - Advancing

    /// The way-in screen's foot, to the point: the same button, the same depth
    /// beneath it, and nothing else in it.
    ///
    /// **The depth is the levelling.** A screen's own space ends where its foot
    /// begins, so the four steps line up with the first page for exactly as long
    /// as their feet are the same. This one used to be a glass button at
    /// `.controlSize(.large)` over 16pt of padding top *and* bottom, which is a
    /// different button at a different height over a foot 20pt deeper - and the
    /// words above it inherited every bit of that.
    private var advanceBar: some View {
        Button {
            advance()
        } label: {
            if isAuthenticating {
                // Tinted against the fill rather than the page, or the spinner
                // is an accent-coloured mark on an accent-coloured capsule.
                ProgressView()
                    .tint(SortyTheme.onAccent)
                    .frame(maxWidth: .infinity)
            } else {
                Text(step.advanceTitle)
            }
        }
        .buttonStyle(OnboardingButton(tint: step == .authorize ? SortyTheme.spotifyGreen : SortyTheme.accent))
        .disabled(!canAdvance)
        .padding(.horizontal, 24)
        .padding(.bottom, OnboardingMetrics.buttonBottom)
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
            hasCopiedRedirectURI = false
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
///
/// **Built on Beam's sheet pattern.** The presentation background is real Liquid
/// Glass rather than the default opaque panel, so the step underneath shows
/// through refracted and the sheet reads as something laid *over* the flow
/// instead of a second screen that replaced it - which matters here, because
/// what it explains is on the page behind it.
///
/// The navigation bar is gone in favour of a centred title with a glass close
/// button on the trailing edge, and the answer is broken into cards on
/// `SortyTheme.surface`. Both are Beam's: solid rows stand out against glass in
/// a way that bare text on a translucent panel does not, and a wall of prose
/// behind an info button is the thing an info button is supposed to spare you.
struct ConnectDetailSheet: View {
    let step: ConnectStep

    /// The value to register, on the one step that registers it.
    ///
    /// **This is where the redirect URI lives now.** It was printed on the page
    /// in a box above the button, which made the create-app step the only one in
    /// the flow carrying a slab of text under its words - a page of onboarding
    /// wearing a form. Behind the ⓘ it is still a tap away for the listener who
    /// wants to check it character by character, which is the only reason to
    /// look at it at all; everyone else copies it with the button and never
    /// needs to see it.
    ///
    /// No copy control here. The page's button is the way to copy it, and
    /// offering a second one is the choice that button exists to remove.
    var redirectURI: String?

    @Environment(\.dismiss) private var dismiss

    /// One card per paragraph.
    ///
    /// `ConnectStep.detail` is written as blank-line-separated paragraphs, each
    /// answering a different question, so they are separated here rather than
    /// run together - which is the whole difference between a reference and a
    /// wall.
    private var paragraphs: [String] {
        step.detail
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 12) {
                    // First, above the prose. Somebody who opened this sheet
                    // from the create-app step opened it to see this.
                    if let redirectURI {
                        redirectURICard(redirectURI)
                    }

                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(SortyTheme.surface, in: .rect(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // Real glass, not the default panel: the step this explains is directly
        // behind it and should stay visible through it.
        .presentationBackground {
            Color.clear
                .glassEffect(.regular, in: Rectangle())
                .ignoresSafeArea()
        }
        .tint(SortyTheme.accent)
    }

    /// The URI, on the same card the paragraphs use so it reads as part of the
    /// answer rather than a control that wandered in from the page.
    ///
    /// Selectable, because checking it against what is in the dashboard is the
    /// job it is here to do, and a listener who wants to compare two strings
    /// character by character should be able to hold one of them.
    private func redirectURICard(_ uri: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Redirect URI")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(uri)
                .font(.body.monospaced())
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(SortyTheme.surface, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        ZStack {
            Text(step.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 56)

            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .glassEffect(.regular, in: .circle)
                        .glassEdge(in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}
