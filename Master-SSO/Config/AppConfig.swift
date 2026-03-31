//
//  AppConfig.swift
//  Master-SSO
//
//  Central configuration for OAuth/OIDC endpoints and client credentials.
//

import Foundation

enum AppConfig {

    // MARK: - Client Credentials

    static let clientId: String = "3f36b455-044c-4632-925a-2d8a987c6d85"
    static let tenantId: String = "50a45856-b465-422f-b6da-bf1ce70c4952"

    // MARK: - Redirect URI
    // MSAL broker format: msauth.<bundle-id>://auth
    // Register this in Azure AD → App Registration → Authentication → iOS/macOS platform.
    // Bundle ID: com.cachatto.Master-SSO
    static let redirectURI: String = "msauth.com.cachatto.Master-SSO://auth"

    // MARK: - Scopes
    // MSAL automatically adds openid, profile, and offline_access — do not repeat them here.
    // User.Read grants access to the signed-in user's basic profile (name, email).
    static let scopes: [String] = ["User.Read"]

    // MARK: - Authority
    static var authorityURL: URL {
        URL(string: "https://login.microsoftonline.com/\(tenantId)")!
    }

    // MARK: - Kept for reference / legacy token exchange (not used with MSAL)
    static var authorizationEndpoint: String {
        "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/authorize"
    }
    static var tokenEndpoint: String {
        "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token"
    }
}
