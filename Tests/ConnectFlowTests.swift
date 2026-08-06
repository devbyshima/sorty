import Foundation
import Testing

/// The guided connect flow's copy and its one checkable input.
@Suite("Connect flow")
struct ConnectFlowTests {

    // MARK: - Client ID

    @Test("A real-shaped Client ID passes")
    func validIDPasses() {
        #expect(ClientIDCheck.check("0123456789abcdef0123456789abcdef") == .valid)
        #expect(ClientIDCheck.check("  0123456789abcdef0123456789abcdef  ") == .valid, "pasted with whitespace")
        #expect(ClientIDCheck.check("0123456789ABCDEF0123456789abcdef") == .valid, "case is not the mistake")
    }

    /// Each failure names what to fix. A single "invalid" would leave the
    /// listener re-pasting the same wrong string.
    @Test("Each way of getting it wrong is distinguishable")
    func failuresAreDistinct() {
        #expect(ClientIDCheck.check("") == .empty)
        #expect(ClientIDCheck.check("   ") == .empty)
        #expect(ClientIDCheck.check("abc") == .wrongLength(3))
        #expect(ClientIDCheck.check(String(repeating: "a", count: 33)) == .wrongLength(33))
        #expect(ClientIDCheck.check("0123456789abcdef0123456789abcdeZ") == .notHexadecimal)

        let problems = [
            ClientIDCheck.empty, .wrongLength(3), .notHexadecimal,
        ].map(\.problem)
        #expect(problems.allSatisfy { $0 != nil })
        #expect(Set(problems.map { $0 ?? "" }).count == 3, "three failures, three explanations")
        #expect(ClientIDCheck.valid.problem == nil)
    }

    /// The commonest paste error on that dashboard page is the *other*
    /// 32-character string, so the length message names it.
    @Test("A truncated paste is told what it might have been")
    func lengthProblemMentionsTheSecret() {
        guard let problem = ClientIDCheck.wrongLength(20).problem else {
            Issue.record("no explanation")
            return
        }
        #expect(problem.contains("20"))
        #expect(problem.contains("32"))
        #expect(problem.contains("Secret"))
    }

    // MARK: - Steps

    @Test("The flow is four steps, in order, each numbered")
    func stepsAreOrdered() {
        #expect(ConnectStep.allCases == [.why, .createApp, .clientID, .authorize])
        #expect(ConnectStep.why.previous == nil)
        #expect(ConnectStep.authorize.next == nil)
        #expect(ConnectStep.why.next == .createApp)
        #expect(ConnectStep.clientID.previous == .createApp)
        #expect(ConnectStep.why.position == "Step 1 of 4")
        #expect(ConnectStep.authorize.position == "Step 4 of 4")
    }

    /// The requirement has to read as a platform constraint rather than an
    /// arbitrary demand, which means the first step has to say what the
    /// constraint *is* — story 50.
    @Test("The first step explains the five-listener cap")
    func firstStepNamesTheCap() {
        let body = ConnectStep.why.body
        #expect(body.contains("five listeners"))
        #expect(body.contains("250,000"), "and why the cap can't simply be lifted")
    }

    @Test("Every step carries copy rather than leaving it to a view")
    func everyStepIsWritten() {
        for step in ConnectStep.allCases {
            #expect(!step.title.isEmpty, "\(step)")
            #expect(step.body.count > 40, "\(step)")
            #expect(!step.advanceTitle.isEmpty, "\(step)")
        }
    }

    /// Sortify never wants the secret, and the step where the two strings sit
    /// side by side is where saying so is worth anything.
    @Test("The Client ID step says the secret is never asked for")
    func clientIDStepDisownsTheSecret() {
        #expect(ConnectStep.clientID.body.contains("secret"))
    }
}

/// Where the app starts, and what happens when connecting doesn't work out.
@Suite("Launch state")
@MainActor
struct LaunchStateTests {

    private func session() -> SessionModel {
        SessionModel(
            configurationStore: ConfigurationStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
            tokenStore: InMemoryTokenStore()
        )
    }

    /// ADR-0003. The highest-friction moment in the product must not sit before
    /// any demonstration of its value.
    @Test("The app launches into a live Demo Mode session")
    func launchesIntoDemo() async {
        let session = session()
        await session.restore()

        #expect(session.stage == .ready)
        #expect(session.isDemo)
        #expect(!session.playlists.isEmpty, "arranging something is possible immediately")
        #expect(session.connectFailure == nil)
    }

    /// Configured for Spotify but with no usable token — the state a listener
    /// lands in after reinstalling. A landing screen here would be a wall on
    /// launch.
    @Test("A configured account that can't be resumed falls back to Demo Mode")
    func unusableCredentialsFallBack() async {
        let session = session()
        session.configuration.clientID = "0123456789abcdef0123456789abcdef"
        session.configuration.serviceMode = .spotify

        await session.restore()

        #expect(session.stage == .ready)
        #expect(session.isDemo)
        #expect(!session.playlists.isEmpty)
    }

    @Test("Signing out returns to Demo Mode rather than to nothing")
    func signOutReturnsToDemo() async {
        let session = session()
        await session.restore()
        await session.signOut()

        #expect(session.stage == .ready)
        #expect(session.isDemo)
        #expect(!session.playlists.isEmpty)
    }

    /// Cancelling is not failing. The listener changed their mind and lands
    /// back where they were with nothing to explain away.
    @Test("A cancelled sign-in leaves no failure to explain")
    func cancellingIsNotFailing() async {
        let session = session()
        await session.restore()
        await session.signInFailed(SpotifyAuthError.cancelled)

        #expect(session.isDemo)
        #expect(session.connectFailure == nil)
    }

    @Test("A real failure is carried into the flow rather than staged")
    func failureIsCarried() async {
        let session = session()
        await session.restore()
        await session.signInFailed(SpotifyAuthError.denied("access_denied"))

        #expect(session.stage == .ready, "the session stays usable")
        #expect(session.isDemo)
        #expect(session.connectFailure?.contains("access_denied") == true)

        session.beginConnecting()
        #expect(session.connectFailure == nil, "a retry doesn't open under the last error")
    }

    /// The boundary the whole flow exists to explain.
    @Test("Demo Mode refuses writes, which is what Save leads off")
    func demoModeCannotWrite() async {
        let session = session()
        await session.restore()

        #expect(!session.service.canWriteBack)
        let model = session.makeTrackListModel(for: session.playlists[0])
        await model.load()
        model.apply(.attribute(.bpm, .descending))
        #expect(!model.canSave)
    }
}
