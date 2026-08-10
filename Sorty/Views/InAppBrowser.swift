import AuthenticationServices
import SwiftUI

/// A web page, opened without leaving Sorty and **on the same cookies the
/// sign-in uses**.
///
/// Setting up an account means visiting Spotify's developer dashboard: creating
/// an application, copying a Client ID out of it, and pasting that back into a
/// field on the screen you just left. Handing that to Safari made it a
/// three-app errand - Sorty, Safari, back to Sorty - across which the listener
/// has to hold a string in their head and the redirect URI they were told to
/// copy is two apps away. That is why it is in-app, and that has not changed.
///
/// **What changed is which cookie jar it reads.** This was an
/// `SFSafariViewController`, on a comment that said it "shares cookies and
/// website data with Safari - so anyone already signed in to Spotify stays
/// signed in". That was true when it was written and stopped being true in iOS
/// 11: Safari view controllers were cut off from Safari's data that release and
/// given a store private to each app. So the dashboard login landed in Sorty's
/// own jar, the authorisation two steps later read *Safari's* through
/// `ASWebAuthenticationSession`, and a listener already signed in to Spotify
/// everywhere else on their phone was asked for their password anyway - once
/// here, and again at the end. Nobody noticed for as long as the comment said
/// otherwise.
///
/// `ASWebAuthenticationSession` with `prefersEphemeralWebBrowserSession = false`
/// is the only surface iOS offers that stays inside the app *and* reads Safari's
/// jar. So the dashboard opens through the same door the sign-in does, and the
/// two share one login.
///
/// **This is an authentication API used to show a page, and that is deliberate
/// rather than careless.** What it costs: the system asks "Sorty wants to use
/// spotify.com to sign in" before the page appears, and there is no address bar.
/// Both are honest here - a dashboard visit *is* a sign-in to Spotify, and the
/// alert names the site rather than taking the listener's word for it.
///
/// Still not a `WKWebView`. This is somebody's account, and a login form
/// deserves the system's chrome rather than a frame Sorty drew: a web view we
/// own could read the password typed into it, and asking to be trusted not to is
/// the thing OAuth's in-app-browser rules exist to prevent.
@MainActor
final class InAppBrowser: NSObject, ASWebAuthenticationPresentationContextProviding {
    /// Held for as long as the page is up.
    ///
    /// `ASWebAuthenticationSession` has to be kept alive by its caller: let go
    /// of after `start()`, it can be deallocated out from under the page it is
    /// showing. Cleared in the completion handler, which is also what stops a
    /// second tap from stacking a second session.
    private var session: ASWebAuthenticationSession?

    private var anchor: ASPresentationAnchor?

    /// A scheme this app is registered for and no page will ever navigate to.
    ///
    /// The API is built to close on a callback, and browsing has none - but it
    /// still demands one. Sorty's own scheme is used rather than an invented
    /// one so the value is registered in `CFBundleURLTypes`; the path is
    /// nonsense on purpose, so a `sorty://callback` link on some page cannot
    /// dismiss the browser out from under the reader.
    private static let neverCalledBack = ASWebAuthenticationSession.Callback.customScheme("sorty")

    /// Opens `url`, or does nothing if there is no window to open it over.
    ///
    /// Nothing to report either way: a browser that will not open has no error
    /// worth interrupting setup for, and the step it was opened from still says
    /// what to do.
    func open(_ url: URL) {
        guard session == nil, let anchor = PresentationAnchor.current() else { return }
        self.anchor = anchor

        let session = ASWebAuthenticationSession(
            url: url,
            callback: Self.neverCalledBack
        ) { [weak self] _, _ in
            // Nothing to hand back. This is a visit rather than a sign-in, so
            // it ends when the listener taps Done - which arrives here as
            // `canceledLogin` and means only that they have finished reading.
            self?.session = nil
        }

        session.presentationContextProvider = self
        // The whole point. `true` here would be a private window, which is the
        // one thing this must not be: it would put the dashboard back on a jar
        // of its own and ask for the password twice again.
        session.prefersEphemeralWebBrowserSession = false
        session.start()
        self.session = session
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let anchor = anchor ?? PresentationAnchor.current() else {
            preconditionFailure("Browser opened without a window scene")
        }
        return anchor
    }
}

/// Where Spotify's dashboard lives, in one place rather than spelled out at each
/// call site.
enum SpotifyLinks {
    /// Force-unwrapped, and that is the honest form: a literal that does not
    /// parse is a mistake in this line rather than a condition the app can find
    /// itself in.
    static let dashboard = URL(string: "https://developer.spotify.com/dashboard")!
}
