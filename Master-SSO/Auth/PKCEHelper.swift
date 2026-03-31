//
//  PKCEHelper.swift
//  Master-SSO
//
//  Generates RFC-7636 PKCE (Proof Key for Code Exchange) parameters.
//  Uses CryptoKit for SHA-256 and SecRandomCopyBytes for entropy.
//

import CryptoKit
import Foundation

/// Immutable PKCE parameter pair produced by PKCEHelper.
struct PKCEParams {
    /// Random 43-128 character high-entropy verifier string (kept secret).
    let verifier: String
    /// BASE64URL( SHA256( verifier ) ) — sent in the authorization request.
    let challenge: String
}

enum PKCEHelper {

    /// Generates a cryptographically random PKCE verifier and its S256 challenge.
    /// - Throws: `AuthError.pkceGenerationFailed` if secure random generation fails.
    static func generate() throws -> PKCEParams {
        // 32 random bytes → 43-char base64url verifier (well within RFC range).
        var rawBytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, rawBytes.count, &rawBytes)
        guard status == errSecSuccess else {
            throw AuthError.pkceGenerationFailed
        }

        let verifier = Data(rawBytes)
            .base64EncodedString()
            .base64URLEncoded()

        let challengeData = Data(SHA256.hash(data: Data(verifier.utf8)))
        let challenge = challengeData
            .base64EncodedString()
            .base64URLEncoded()

        return PKCEParams(verifier: verifier, challenge: challenge)
    }
}

// MARK: - Base64URL helpers

private extension String {
    /// Converts standard Base64 to Base64URL (RFC 4648 §5) by stripping padding
    /// and replacing '+' / '/' with '-' / '_'.
    func base64URLEncoded() -> String {
        self
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
