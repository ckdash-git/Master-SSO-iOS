//
//  TokenResponse.swift
//  Master-SSO
//
//  Decodable model for the JSON body returned by the token endpoint.
//  Converts to AuthToken for persistence and app-state consumption.
//

import Foundation

struct TokenResponse: Decodable {

    let accessToken: String?
    let tokenType: String
    let expiresIn: Int?
    let scope: String?
    let idToken: String?
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case tokenType    = "token_type"
        case expiresIn    = "expires_in"
        case scope
        case idToken      = "id_token"
        case refreshToken = "refresh_token"
    }

    // MARK: - Conversion

    /// Maps the raw token response to the app's internal AuthToken representation.
    func toAuthToken() -> AuthToken {
        let expirationInterval = TimeInterval(expiresIn ?? 3600)
        let expiresAt = Date().addingTimeInterval(expirationInterval)

        return AuthToken(
            idToken:      idToken,
            accessToken:  accessToken,
            refreshToken: refreshToken,
            expiresAt:    expiresAt,
            tokenType:    tokenType,
            scope:        scope
        )
    }
}
