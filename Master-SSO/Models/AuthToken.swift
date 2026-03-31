//
//  AuthToken.swift
//  Master-SSO
//
//  Persisted representation of the tokens received after successful authentication.
//  Stored as JSON in the Keychain by TokenManager.
//

import Foundation

struct AuthToken: Codable, Equatable {

    let idToken: String?
    let accessToken: String?
    let refreshToken: String?
    let expiresAt: Date
    let tokenType: String
    let scope: String?

    // MARK: - Validity

    /// True when the current time is at or past the token's expiry.
    var isExpired: Bool { Date() >= expiresAt }

    // MARK: - User identity (decoded from the ID token)

    /// The user's email address, extracted from the ID token payload.
    var userEmail: String? {
        guard let idToken else { return nil }
        return JWTParser.email(from: idToken)
    }

    /// The user's display name, extracted from the ID token payload.
    var userName: String? {
        guard let idToken else { return nil }
        return JWTParser.name(from: idToken)
    }

    /// Returns the best available display identifier (email → name → nil).
    var displayIdentifier: String? { userEmail ?? userName }
}
