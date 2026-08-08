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
    /// constraint *is* - story 50.
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

    /// ADR-0007. Demo Mode is gone from the shipped app, so a first run has no
    /// session to land in and the way-in screen is the state rather than a
    /// once-only moment. ADR-0003 refused exactly this, on friction grounds
    /// that are real and are now accepted rather than solved.
    @Test("A first run lands signed out")
    func firstRunLandsSignedOut() async {
        let session = session()
        await session.restore()

        #expect(session.stage == .signedOut)
        #expect(!session.isConnected)
        #expect(session.playlists.isEmpty)
        #expect(session.connectFailure == nil)
    }

    /// Configured but with no usable token - the state a listener lands in
    /// after reinstalling. It is a wall, and it is the front door.
    @Test("A configured account that can't be resumed lands signed out")
    func unusableCredentialsLandSignedOut() async {
        let session = session()
        session.configuration.clientID = "0123456789abcdef0123456789abcdef"

        await session.restore()

        #expect(session.stage == .signedOut)
        #expect(session.playlists.isEmpty)
    }

    @Test("Signing out lands where a first run begins")
    func signOutLandsSignedOut() async {
        let session = session()
        await session.restore()
        await session.signOut()

        #expect(session.stage == .signedOut)
        #expect(!session.isConnected)
        #expect(session.playlists.isEmpty)
    }

    /// Cancelling is not failing. The listener changed their mind and lands
    /// back where they were with nothing to explain away.
    @Test("A cancelled sign-in leaves no failure to explain")
    func cancellingIsNotFailing() async {
        let session = session()
        await session.restore()
        await session.signInFailed(SpotifyAuthError.cancelled)

        #expect(session.stage == .signedOut)
        #expect(session.connectFailure == nil)
    }

    @Test("A real failure is carried into the flow rather than staged")
    func failureIsCarried() async {
        let session = session()
        await session.restore()
        await session.signInFailed(SpotifyAuthError.denied("access_denied"))

        #expect(session.stage == .signedOut)
        #expect(session.connectFailure?.contains("access_denied") == true)

        session.beginConnecting()
        #expect(session.connectFailure == nil, "a retry doesn't open under the last error")
    }

    /// The seam ADR-0007 leaves for the screenshot harness, asserted here
    /// because nothing else can: if it breaks, 31 screenshots photograph an
    /// empty library rather than failing, and the set still looks plausible.
    @Test("Demo data is reachable only by asking for it")
    func demoDataIsReachableForTheHarness() async {
        let plain = session()
        await plain.restore()
        #expect(plain.playlists.isEmpty, "nothing arrives without the flag")

        let demo = SessionModel(
            configurationStore: ConfigurationStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
            tokenStore: InMemoryTokenStore(),
            usesDemoData: true
        )
        await demo.restore()

        #expect(demo.stage == .ready)
        #expect(!demo.playlists.isEmpty, "the harness has a library to photograph")
    }

    /// The boundary the whole flow exists to explain.
    /// Save is armed by `canWriteBack`, and a session without an account must
    /// refuse it - which is what makes the Save anchor open the connect flow
    /// instead of writing. Asserted through the demo session because it is the
    /// only non-writable one that has a playlist to build a model from.
    @Test("A session with no account refuses writes, which is what Save leads off")
    func sessionWithoutAnAccountCannotWrite() async {
        let unconnected = session()
        await unconnected.restore()
        #expect(!unconnected.service.canWriteBack)

        let demo = SessionModel(
            configurationStore: ConfigurationStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
            tokenStore: InMemoryTokenStore(),
            usesDemoData: true
        )
        await demo.restore()

        #expect(!demo.service.canWriteBack)
        let model = demo.makeTrackListModel(for: demo.playlists[0])
        await model.load()
        model.apply(.attribute(.bpm, .descending))
        #expect(!model.canSave)
    }
}
