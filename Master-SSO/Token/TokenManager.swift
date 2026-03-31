//
//  TokenManager.swift
//  Master-SSO
//
//  Higher-level manager that serialises/deserialises AuthToken as JSON and
//  delegates raw byte storage to KeychainService.
//
//  Single responsibility: tokens in ↔ tokens out. All Keychain details are
//  encapsulated below.
//

import Foundation
import os

final class TokenManager {

    static let shared = TokenManager()
    private init() {}

    private let keychain = KeychainService.shared
    private let logger   = AppLogger.token
    private let tokenKey = "master_sso_auth_token"

    // MARK: - Write

    /// Encodes `token` as JSON and saves it to the Keychain.
    func save(token: AuthToken) throws {
        let data = try JSONEncoder().encode(token)
        try keychain.save(data, forKey: tokenKey)
        logger.info("AuthToken persisted to Keychain (expires: \(token.expiresAt))")
    }

    // MARK: - Read

    /// Loads and decodes the stored AuthToken.
    /// Returns nil if no token is present or decoding fails.
    func loadToken() -> AuthToken? {
        do {
            let data  = try keychain.load(forKey: tokenKey)
            let token = try JSONDecoder().decode(AuthToken.self, from: data)
            logger.debug("AuthToken loaded from Keychain")
            return token
        } catch KeychainError.itemNotFound {
            logger.debug("No AuthToken stored in Keychain")
            return nil
        } catch {
            logger.warning("Failed to decode stored AuthToken: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Delete

    /// Removes all stored tokens (called on sign-out).
    func deleteAll() {
        keychain.delete(forKey: tokenKey)
        logger.info("All tokens deleted from Keychain")
    }

    // MARK: - Convenience

    /// True when a non-expired token is present in the Keychain.
    var hasValidToken: Bool {
        guard let token = loadToken() else { return false }
        return !token.isExpired
    }
}
