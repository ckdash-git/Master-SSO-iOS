//
//  AppConfig.swift
//  Master-SSO
//
//  Central configuration for OAuth/OIDC endpoints and client credentials.
//  Replace placeholder values with your actual Azure AD App Registration details
//  before running the app.
//

import Foundation

enum AppConfig {

    // MARK: - Client Credentials
    // Obtain these from your Azure AD App Registration (or custom IdP admin console).

    /// Azure AD Application (client) ID registered for this app.
    static let clientId: String = "YOUR_AZURE_APP_CLIENT_ID"

    /// Azure AD tenant ID, or "common" / "organizations" for multi-tenant.
    static let tenantId: String = "YOUR_TENANT_ID_OR_common"

    // MARK: - Redirect URI
    // Must match exactly what is registered in your App Registration's
    // "Redirect URIs" list (type: Public client / native).
    // Also add the scheme portion ("master-sso") to Info.plist CFBundleURLTypes.

    static let redirectURI: String = "master-sso://auth/callback"

    // MARK: - Scopes
    // openid / profile / email  → required for ID token claims
    // offline_access            → enables refresh token issuance

    static let scopes: String = "openid profile email offline_access"

    // MARK: - Endpoints
    // Microsoft's authorization server federates automatically to your custom IdP
    // (e.g., Okta, Ping, ADFS) based on the tenant's home-realm-discovery policy.

    static var authorizationEndpoint: String {
        "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/authorize"
    }

    static var tokenEndpoint: String {
        "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token"
    }

    /// Front-channel logout endpoint — used to clear the IdP session on sign-out.
    static var logoutEndpoint: String {
        "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/logout"
    }

    // MARK: - Custom IdP (optional override)
    // If your authentication flow starts directly at your custom IdP rather than
    // at Microsoft, uncomment and update the lines below:
    //
    // static let authorizationEndpoint = "https://your-idp.example.com/oauth2/v2.0/authorize"
    // static let tokenEndpoint         = "https://your-idp.example.com/oauth2/v2.0/token"
}
