//
//  KeychainService.swift
//  Master-SSO
//
//  Low-level wrapper around the Security framework Keychain APIs.
//  Items are stored as kSecClassGenericPassword blobs scoped to the app's
//  bundle identifier and restricted to kSecAttrAccessibleWhenUnlockedThisDeviceOnly
//  (data never leaves the device and is inaccessible while locked).
//

import Foundation
import Security
import os

enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case itemNotFound
    case unexpectedType

    var errorDescription: String? {
        switch self {
        case .saveFailed(let s):  return "Keychain save failed (OSStatus \(s))"
        case .loadFailed(let s):  return "Keychain load failed (OSStatus \(s))"
        case .itemNotFound:       return "Item not found in Keychain"
        case .unexpectedType:     return "Keychain item data type was unexpected"
        }
    }
}

final class KeychainService {

    static let shared = KeychainService()
    private init() {}

    private let service: String = Bundle.main.bundleIdentifier ?? "com.cachatto.Master-SSO"
    private let logger = AppLogger.token

    // MARK: - Write

    /// Persists raw data under `key`, overwriting any existing entry.
    func save(_ data: Data, forKey key: String) throws {
        // Delete first to avoid errSecDuplicateItem.
        deleteItem(forKey: key)

        let query: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrService as String:     service,
            kSecAttrAccount as String:     key,
            kSecValueData as String:       data,
            kSecAttrAccessible as String:  kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Keychain save failed for key '\(key)': OSStatus \(status)")
            throw KeychainError.saveFailed(status)
        }
        logger.debug("Keychain: saved item for key '\(key)'")
    }

    // MARK: - Read

    /// Loads and returns the raw data stored under `key`.
    /// - Throws: `KeychainError.itemNotFound` when the key is absent.
    func load(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            logger.error("Keychain load failed for key '\(key)': OSStatus \(status)")
            throw KeychainError.loadFailed(status)
        }
        guard let data = result as? Data else {
            throw KeychainError.unexpectedType
        }
        logger.debug("Keychain: loaded item for key '\(key)'")
        return data
    }

    // MARK: - Delete

    /// Silently removes the item for `key` (no error if absent).
    func delete(forKey key: String) {
        deleteItem(forKey: key)
        logger.debug("Keychain: deleted item for key '\(key)'")
    }

    // MARK: - Private

    @discardableResult
    private func deleteItem(forKey key: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        return SecItemDelete(query as CFDictionary)
    }
}
