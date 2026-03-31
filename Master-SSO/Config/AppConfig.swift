//
//  AppConfig.swift
//  Master-SSO
//
//  Central configuration for OAuth/OIDC endpoints and client credentials.
//

import Foundation

enum AppConfig {

    // MARK: - Microsoft / Azure AD

    static let clientId: String = "3f36b455-044c-4632-925a-2d8a987c6d85"
    static let tenantId: String = "50a45856-b465-422f-b6da-bf1ce70c4952"

    // MSAL broker format: msauth.<bundle-id>://auth
    // Register in Azure AD → App Registration → Authentication → iOS/macOS platform.
    static let redirectURI: String = "msauth.com.cachatto.Master-SSO://auth"

    // MSAL automatically adds openid, profile, and offline_access — do not repeat them here.
    static let scopes: [String] = ["User.Read"]

    static var authorityURL: URL {
        URL(string: "https://login.microsoftonline.com/\(tenantId)")!
    }

    // MARK: - Google Workspace

    // iOS OAuth 2.0 Client ID from Google Cloud Console →
    //   APIs & Services → Credentials → Create credentials → OAuth client ID → iOS
    //   Application type: iOS, Bundle ID: com.cachatto.Master-SSO
    static let googleClientId: String = "541572207213-mus0961fn7f5pv26ih1qvorvd5cdiibk.apps.googleusercontent.com"

    // Reversed client ID — used as the OAuth callback URL scheme.
    // Derived by reversing the domain parts of googleClientId:
    //   "123456789-abc.apps.googleusercontent.com" → "com.googleusercontent.apps.123456789-abc"
    // Must also be added to CFBundleURLSchemes in Info.plist.
    static let googleReversedClientId: String = "com.googleusercontent.apps.541572207213-mus0961fn7f5pv26ih1qvorvd5cdiibk"

    // MARK: - Legacy reference (not used with MSAL)

    static var authorizationEndpoint: String {
        "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/authorize"
    }
    static var tokenEndpoint: String {
        "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token"
    }
}
