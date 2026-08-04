import CryptoKit
import Foundation

/// Proof Key for Code Exchange. Lets a native app run the authorization-code
/// flow without shipping a client secret it could never keep secret.
public enum PKCE {
    private static let unreserved = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    /// RFC 7636 requires 43–128 characters from the unreserved set.
    public static func codeVerifier(length: Int = 64) -> String {
        precondition((43...128).contains(length), "PKCE verifier must be 43–128 characters")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { unreserved[Int($0) % unreserved.count] })
    }

    public static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncode(Data(digest))
    }

    public static func state(length: Int = 16) -> String {
        codeVerifier(length: max(43, length))
    }

    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
