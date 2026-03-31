//
//  AuthError.swift
//  Master-SSO
//
//  Typed errors covering every failure mode in the authentication pipeline.
//

import Foundation

enum AuthError: Error, LocalizedError {

    // MARK: - Session errors
    case invalidURL
    case userCancelled
    case sessionError(Error)
    case invalidCallback

    // MARK: - Authorization errors
    case authorizationFailed(String)

    // MARK: - Token errors
    case tokenExchangeFailed(statusCode: Int, body: String)
    case tokenDecodingFailed

    // MARK: - PKCE
    case pkceGenerationFailed

    // MARK: - Catch-all
    case unknown(Error)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The authorization URL could not be constructed."
        case .userCancelled:
            return "Sign-in was cancelled."
        case .sessionError(let error):
            return "Authentication session error: \(error.localizedDescription)"
        case .invalidCallback:
            return "The redirect callback URL was invalid or missing."
        case .authorizationFailed(let message):
            return "Authorization failed: \(message)"
        case .tokenExchangeFailed(let code, let body):
            return "Token exchange failed (HTTP \(code)): \(body)"
        case .tokenDecodingFailed:
            return "The token response could not be decoded."
        case .pkceGenerationFailed:
            return "Failed to generate cryptographic PKCE parameters."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
