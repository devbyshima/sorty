import SafariServices
import SwiftUI

/// A web page, opened without leaving Sorty.
///
/// Setting up an account means visiting Spotify's developer dashboard: creating
/// an application, copying a Client ID out of it, and pasting that back into a
/// field on the screen you just left. Handing that to Safari made it a
/// three-app errand - Sorty, Safari, back to Sorty - across which the listener
/// has to hold a string in their head and the redirect URI they were told to
/// copy is two apps away.
///
/// `SFSafariViewController` keeps all of it here. It is a full browser with a
/// real address bar and Reader, it **shares cookies and website data with
/// Safari** - so anyone already signed in to Spotify stays signed in - and the
/// dashboard closes back onto the field that wants what it gave them.
///
/// Not a `WKWebView`: this is somebody's account, and a login form deserves the
/// browser's own chrome saying whose site it is. A web view we drew ourselves
/// would ask them to trust an address bar we control.
struct InAppBrowser: UIViewControllerRepresentable {
    let url: URL
    var tint: Color = SortyTheme.accent

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        // Reader is not what anybody wants from a developer dashboard, and the
        // bar collapsing on scroll costs the address the trust it is there for.
        configuration.entersReaderIfAvailable = false

        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.preferredControlTintColor = UIColor(tint)
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// A `URL` that a `.sheet(item:)` will accept.
///
/// `URL` is not `Identifiable`, and the alternative - a separate `Bool` beside a
/// stored URL - is two pieces of state that can disagree.
struct BrowsableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }

    init?(_ string: String) {
        guard let url = URL(string: string) else { return nil }
        self.url = url
    }
}

/// Where Spotify's dashboard lives, in one place rather than spelled out at each
/// call site.
enum SpotifyLinks {
    static var dashboard: BrowsableURL? { BrowsableURL("https://developer.spotify.com/dashboard") }
}
