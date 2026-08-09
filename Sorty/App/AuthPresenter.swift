import AuthenticationServices
import SwiftUI

/// Runs the Spotify consent flow in `ASWebAuthenticationSession`.
///
/// This is the only correct surface for OAuth on iOS: it shares Safari's cookie
/// jar (so an already-signed-in listener gets a one-tap approval), shows the
/// system's own consent prompt, and hands the callback URL straight back -
/// unlike `SFSafariViewController`, which can't see the redirect, or a
/// `WKWebView`, which would put Sorty between the user and their password.
@MainActor
final class AuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    /// Resolved in `authenticate(url:redirectURI:)` before the session starts.
    private var anchor: ASPresentationAnchor?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // `authenticate` resolves and stores this, and throws if it can't, so by
        // the time the session asks there is always one. The protocol demands a
        // non-optional and iOS 27 has no sceneless UIWindow initialiser left to
        // fabricate a placeholder with.
        guard let anchor = anchor ?? Self.currentAnchor() else {
            preconditionFailure("Authentication session started without a window scene")
        }
        return anchor
    }

    private static func currentAnchor() -> ASPresentationAnchor? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        else { return nil }
        return scene.keyWindow ?? ASPresentationAnchor(windowScene: scene)
    }

    /// Presents the flow and resolves with the callback URL.
    ///
    /// `redirectURI` decides how the callback is matched. Spotify's dashboard
    /// has been rejecting custom schemes as insecure for Client IDs created
    /// since April 2025, so an https redirect has to work too - that path needs
    /// a matching `apple-app-site-association` on the host.
    func authenticate(url: URL, redirectURI: String) async throws -> URL {
        guard let callback = Self.callback(for: redirectURI) else {
            throw SpotifyAuthError.notConfigured
        }
        guard let anchor = Self.currentAnchor() else {
            throw SpotifyAuthError.notConfigured
        }
        self.anchor = anchor

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callback: callback
            ) { callbackURL, error in
                if let error {
                    let code = (error as NSError).code
                    if code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: SpotifyAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: SpotifyAuthError.missingCode)
                    return
                }
                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            // Deliberately false: reusing the Safari session is the whole point,
            // and an ephemeral session would force a password entry every time.
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    /// An https redirect becomes a universal-link callback; anything else is
    /// matched by its custom scheme.
    private static func callback(for redirectURI: String) -> ASWebAuthenticationSession.Callback? {
        guard let components = URLComponents(string: redirectURI.trimmingCharacters(in: .whitespaces)),
              let scheme = components.scheme
        else { return nil }

        if scheme.lowercased() == "https" {
            guard let host = components.host, !host.isEmpty else { return nil }
            let path = components.path.isEmpty ? "/" : components.path
            return .https(host: host, path: path)
        }
        return .customScheme(scheme)
    }
}
