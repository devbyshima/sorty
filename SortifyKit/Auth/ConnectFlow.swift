import Foundation

/// What a pasted Client ID looks like before anyone tries to sign in with it.
///
/// A wrong Client ID otherwise fails at the far end of a web authentication
/// sheet with Spotify's own `INVALID_CLIENT`, which arrives minutes after the
/// mistake and doesn't say which of the two 32-character strings on the
/// dashboard was the wrong one to copy. This catches the paste errors that can
/// be caught without a network, and says what to fix.
///
/// It is not a claim that the ID is *real* — only the authorisation can settle
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
            "That's \(count) characters — a Client ID is exactly 32. Check you copied the whole thing, and that it isn't the Client Secret."
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
        case .why: "Sortify needs your own Spotify app"
        case .createApp: "Create the app"
        case .clientID: "Paste the Client ID"
        case .authorize: "Sign in to Spotify"
        }
    }

    /// The point of the step, in the fewest words that still explain rather
    /// than instruct.
    public var body: String {
        switch self {
        case .why:
            """
            Spotify caps a single application at five listeners. If Sortify \
            shipped with one Client ID built in, the sixth person to open it \
            would be locked out — and lifting the cap needs 250,000 monthly \
            listeners, which an app that can't reach its sixth user will never \
            have.

            So everyone brings their own. It's free, and it takes about two \
            minutes.
            """
        case .createApp:
            """
            On Spotify's developer dashboard, create an app — any name and \
            description will do. Add the redirect URI below exactly as it \
            appears, then add your own Spotify account under Users Management.

            Two things worth knowing before you start: a development-mode app \
            admits at most five listeners, and its owner needs Spotify Premium.
            """
        case .clientID:
            """
            Your app's page shows a Client ID and a Client Secret. Sortify \
            needs the Client ID — the secret never leaves Spotify's dashboard \
            and Sortify will never ask for it.
            """
        case .authorize:
            """
            Sign-in runs in Apple's own web authentication sheet, so Sortify \
            never sees your password. This is also where the Client ID gets \
            proved: if it's wrong, Spotify says so here.
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
