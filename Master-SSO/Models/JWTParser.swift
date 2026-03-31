//
//  JWTParser.swift
//  Master-SSO
//
//  Lightweight, no-dependency JWT payload decoder.
//  Only Base64URL-decodes the claims segment — does NOT verify the signature.
//  Signature verification is performed server-side by the token endpoint.
//
//  Use only for extracting user-facing display claims (name, email).
//

import Foundation

enum JWTParser {

    // MARK: - Claim extraction

    /// Extracts the user's email from the `email` or `preferred_username` claim.
    static func email(from token: String) -> String? {
        let c = claims(from: token)
        return c?["email"] as? String
            ?? c?["preferred_username"] as? String
    }

    /// Extracts the user's display name from the `name` claim.
    static func name(from token: String) -> String? {
        claims(from: token)?["name"] as? String
    }

    // MARK: - Raw claim dictionary

    /// Decodes the JWT payload segment.
    /// Returns nil if the token is malformed or the payload cannot be decoded.
    static func claims(from token: String) -> [String: Any]? {
        let segments = token.components(separatedBy: ".")
        guard segments.count == 3 else { return nil }

        var base64 = segments[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Re-add Base64 padding stripped during encoding
        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(contentsOf: String(repeating: "=", count: 4 - remainder))
        }

        guard
            let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        return json
    }
}
