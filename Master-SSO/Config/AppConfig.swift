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

    // MARK: - Custom IdP (Casdoor)
    // Primary authentication entry point — the IdP page lets the user pick their
    // identity provider (Microsoft, Google, …) and handles federation.

    static let idpClientId:     String = "e5aaa54896509de4b41a"
    // NOTE: storing client_secret in a native app binary is acceptable for internal
    // tooling but should be removed once the Casdoor app is set to "public" client.
    static let idpClientSecret: String = "f6a21ebc4716d86a96bab263656d43f1208150e8"
    // Registered as an allowed redirect URI in Casdoor → Applications → your app
    static let idpRedirectURI:  String = "master-sso://oauth/callback"

    static let idpAuthorizationEndpoint: String = "https://cachatto.click/login/oauth/authorize"
    static let idpTokenEndpoint:         String = "https://cachatto.click/api/login/oauth/access_token"
    static let idpUserInfoEndpoint:      String = "https://cachatto.click/api/userinfo"
    static let idpIssuer:                String = "https://cachatto.click"

    // MARK: - Legacy reference (not used with MSAL)

    static var authorizationEndpoint: String {
        "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/authorize"
    }
    static var tokenEndpoint: String {
        "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token"
    }
}
