import Foundation

/// What a pasted Client ID looks like before anyone tries to sign in with it.
///
/// A wrong Client ID otherwise fails at the far end of a web authentication
/// sheet with Spotify's own `INVALID_CLIENT`, which arrives minutes after the
/// mistake and doesn't say which of the two 32-character strings on the
/// dashboard was the wrong one to copy. This catches the paste errors that can
/// be caught without a network, and says what to fix.
///
/// It is not a claim that the ID is *real* - only the authorisation can settle
/// that, which is why the flow never reports success until Spotify has answered.
public enum ClientIDCheck: Equatable, Sendable {
    case valid
    case empty
    /// Spotify's IDs are exactly 32 characters.
    case wrongLength(Int)
    /// Hexadecimal, lowercase. A stray quote or a truncated paste lands here.
    case notHexadecimal

    /// Spotify Client IDs are 32 lowercase hexadecimal characters.
    public static func check(_ raw: String) -> ClientIDCheck {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        guard trimmed.count == 32 else { return .wrongLength(trimmed.count) }
        let hex = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard trimmed.unicodeScalars.allSatisfy(hex.contains) else { return .notHexadecimal }
        return .valid
    }

    public var isValid: Bool { self == .valid }

    /// What to do about it. Written to be read under a text field, so each one
    /// names the mistake rather than restating the rule.
    public var problem: String? {
        switch self {
        case .valid:
            nil
        case .empty:
            "Paste the Client ID from your app's page on the Spotify dashboard."
        case .wrongLength(let count):
            "That's \(count) characters. A Client ID is exactly 32, so check you copied the whole thing, and that it isn't the Client Secret."
        case .notHexadecimal:
            "A Client ID is made of digits and the letters a–f only. Something else came along with the paste."
        }
    }
}

/// The guided connect flow, as steps.
///
/// Each carries its own copy, because the words are the feature: this exists so
/// the Client ID requirement arrives as a platform constraint someone can
/// understand rather than an arbitrary demand, and so the redirect URI can't be
/// got subtly wrong. Copy that a view owns is copy nobody can assert.
public enum ConnectStep: Int, CaseIterable, Identifiable, Sendable, Comparable {
    /// Why this is being asked at all.
    case why
    /// Make the app on Spotify's dashboard.
    case createApp
    /// Paste what it gave you.
    case clientID
    /// Sign in, which is also the only real proof the ID works.
    case authorize

    public var id: Int { rawValue }

    public static func < (lhs: ConnectStep, rhs: ConnectStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var title: String {
        switch self {
        case .why: "Sorty needs your own Spotify app"
        case .createApp: "Create the app"
        case .clientID: "Paste the Client ID"
        case .authorize: "Sign in to Spotify"
        }
    }

    /// The point of the step, in two lines.
    ///
    /// **Two lines is the budget, not a target.** These pages lead with a large
    /// glyph and put their words underneath it, the way Beam's onboarding does,
    /// and that shape only works while the words are short enough to be taken in
    /// at a glance. A paragraph under a 100pt symbol is a paragraph wearing a
    /// hat.
    ///
    /// Everything that did not fit is in ``detail`` rather than deleted. Some of
    /// it is genuinely wanted - by the one listener in ten who asks *why* an app
    /// is making them register a developer application - and none of it should
    /// be in the way of the nine who do not.
    public var body: String {
        switch self {
        case .why:
            "Spotify caps any single app at five listeners, so everyone brings their own. It's free, and takes about two minutes."
        case .createApp:
            "Create an app on Spotify's dashboard, then add the redirect URI below exactly as it appears."
        case .clientID:
            "Your app's page shows a Client ID and a Client Secret. Sorty needs the ID."
        case .authorize:
            "Sign-in runs in Apple's own web sheet, so Sorty never sees your password."
        }
    }

    /// The longer answer, behind the info button.
    ///
    /// This is where the reasoning lives: the arithmetic behind the cap, the
    /// requirements that will stop somebody halfway through, and the promises
    /// about what Sorty does not do with their credentials. It is not filler and
    /// it is not marketing - a listener who opens it has asked a real question,
    /// and every line answers one.
    public var detail: String {
        switch self {
        case .why:
            """
            Spotify allows one application five listeners. If Sorty shipped \
            with a Client ID built in, the sixth person to open it would be \
            locked out.

            Lifting that cap needs 250,000 monthly listeners, which an app that \
            cannot reach its sixth user will never have. So everyone registers \
            their own application, which costs nothing and belongs to them.
            """
        case .createApp:
            """
            Any name and description will do - nobody but you will see them.

            Add the redirect URI exactly as it appears, including the scheme: \
            Spotify matches it character for character, and a URI that is subtly \
            wrong fails later with a message about the application rather than \
            about the one character that differs.

            Then add your own Spotify account under Users Management. The \
            application's owner needs Spotify Premium.
            """
        case .clientID:
            """
            The Client Secret is the other half of the pair, and Sorty never \
            asks for it. It stays on Spotify's dashboard.

            Sorty signs in with PKCE, which is the flow Spotify publishes for \
            applications that cannot keep a secret - a phone app cannot, because \
            anything shipped inside it can be read back out.
            """
        case .authorize:
            """
            Authorization happens in Apple's own web authentication sheet, which \
            Sorty cannot see inside. Your password never reaches this app.

            It is also the only real test of the Client ID: a wrong one is \
            accepted by every screen before this and refused here, by Spotify \
            itself.

            The token that comes back is kept in the device Keychain and never \
            leaves it.
            """
        }
    }

    /// The words on the button that leaves this step.
    public var advanceTitle: String {
        switch self {
        case .why: "Continue"
        case .createApp: "I've created the app"
        case .clientID: "Continue"
        case .authorize: "Connect Spotify"
        }
    }

    public var next: ConnectStep? { ConnectStep(rawValue: rawValue + 1) }
    public var previous: ConnectStep? { ConnectStep(rawValue: rawValue - 1) }

    /// One-based, for "Step 2 of 4".
    public var position: String { "Step \(rawValue + 1) of \(ConnectStep.allCases.count)" }
}
