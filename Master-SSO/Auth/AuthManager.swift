//
//  AuthManager.swift
//  Master-SSO
//
//  Authenticates via MSAL (Microsoft Authentication Library) with broker support.
//
//  Broker flow (when Microsoft Authenticator is installed):
//    1. MSAL detects Authenticator and delegates authentication to it.
//    2. Authenticator performs the federated login (Microsoft → custom IdP).
//    3. The resulting tokens are stored in the shared MSAL broker cache.
//    4. Teams and Outlook (also MSAL-based) find the token silently — no re-login.
//
//  Non-broker fallback (Authenticator not installed):
//    MSAL opens ASWebAuthenticationSession in the system browser and performs
//    PKCE-based auth directly. The shared Safari session cookie still gives
//    best-effort SSO for Teams/Outlook.
//
//  Azure AD requirement:
//    Register an iOS platform in your App Registration:
//      Authentication → Add a platform → iOS/macOS
//      Bundle ID: com.cachatto.Master-SSO
//      (Azure auto-generates the redirect URI: msauth.com.cachatto.Master-SSO://auth)
//

import Combine
import Foundation
import MSAL
import os
import UIKit

@MainActor
final class AuthManager: ObservableObject {

    static let shared = AuthManager()

    // MARK: - Published state

    enum AuthState: Equatable {
        case unauthenticated
        case authenticating
        case authenticated(AuthToken)
        case failed(String)

        static func == (lhs: AuthState, rhs: AuthState) -> Bool {
            switch (lhs, rhs) {
            case (.unauthenticated, .unauthenticated): return true
            case (.authenticating,  .authenticating):  return true
            case (.authenticated,   .authenticated):   return true
            case (.failed(let a),   .failed(let b)):   return a == b
            default: return false
            }
        }
    }

    @Published private(set) var authState: AuthState = .unauthenticated

    var isAuthenticated: Bool {
        if case .authenticated = authState { return true }
        return false
    }

    // MARK: - Private

    private let logger = AppLogger.auth
    private var msalApp: MSALPublicClientApplication?

    private init() {
        setupMSAL()
        restoreSessionIfValid()
    }

    // MARK: - MSAL setup

    private func setupMSAL() {
        do {
            let authority = try MSALAADAuthority(url: AppConfig.authorityURL)
            let config = MSALPublicClientApplicationConfig(
                clientId: AppConfig.clientId,
                redirectUri: AppConfig.redirectURI,
                authority: authority
            )
            msalApp = try MSALPublicClientApplication(configuration: config)
            logger.info("MSAL configured — clientId: \(AppConfig.clientId)")
        } catch {
            logger.error("MSAL setup failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Public API

    /// Starts interactive sign-in via MSAL.
    /// If Microsoft Authenticator is installed, it acts as a broker and tokens
    /// are shared with Teams / Outlook automatically.
    func signIn() async {
        guard authState != .authenticating else {
            logger.warning("Sign-in already in progress — ignoring duplicate call")
            return
        }
        guard let msalApp else {
            authState = .failed("MSAL is not configured. Check clientId and authority.")
            return
        }

        logger.info("MSAL auth flow started")
        authState = .authenticating

        do {
            let viewController = try presentingViewController()
            let webviewParams   = MSALWebviewParameters(authPresentationViewController: viewController)
            // .default uses the system browser / broker — required for broker SSO.
            webviewParams.webviewType = .default

            let params = MSALInteractiveTokenParameters(
                scopes: AppConfig.scopes,
                webviewParameters: webviewParams
            )
            params.promptType = .selectAccount

            let result = try await acquireToken(app: msalApp, parameters: params)
            let token  = makeAuthToken(from: result)

            try TokenManager.shared.save(token: token)
            authState = .authenticated(token)
            logger.info("MSAL auth completed — account: \(result.account.username ?? "unknown")")

        } catch let nsError as NSError where isCancelledError(nsError) {
            logger.info("Sign-in cancelled by user")
            authState = .unauthenticated

        } catch let nsError as NSError {
            let sub = nsError.userInfo[MSALInternalErrorCodeKey] as? Int ?? 0
            let desc = nsError.userInfo[MSALErrorDescriptionKey] as? String ?? nsError.localizedDescription
            let oauthErr = nsError.userInfo[MSALOAuthErrorKey] as? String ?? ""
            logger.error("MSAL auth failed — domain: \(nsError.domain) code: \(nsError.code) sub: \(sub) oauth: \(oauthErr) — \(desc)")
            authState = .failed(desc)
        }
    }

    /// Removes the MSAL account and clears local state.
    func signOut() {
        logger.info("Sign-out initiated")
        if let msalApp {
            do {
                let accounts = try msalApp.allAccounts()
                for account in accounts {
                    try msalApp.remove(account)
                    logger.debug("Removed MSAL account: \(account.username ?? "?")")
                }
            } catch {
                logger.error("MSAL account removal error: \(error.localizedDescription)")
            }
        }
        TokenManager.shared.deleteAll()
        authState = .unauthenticated
        logger.info("Sign-out complete")
    }

    // MARK: - Session restoration

    private func restoreSessionIfValid() {
        guard let token = TokenManager.shared.loadToken(), !token.isExpired else {
            logger.debug("No valid token found in Keychain — presenting login")
            return
        }
        authState = .authenticated(token)
        logger.info("Session restored from Keychain")
    }

    // MARK: - Helpers

    /// Wraps MSAL's completion-handler-based acquireToken in async/await.
    private func acquireToken(
        app: MSALPublicClientApplication,
        parameters: MSALInteractiveTokenParameters
    ) async throws -> MSALResult {
        try await withCheckedThrowingContinuation { continuation in
            app.acquireToken(with: parameters) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthError.invalidCallback)
                }
            }
        }
    }

    private func makeAuthToken(from result: MSALResult) -> AuthToken {
        AuthToken(
            idToken:      result.idToken,
            accessToken:  result.accessToken,
            refreshToken: nil,         // MSAL manages refresh tokens internally
            expiresAt:    result.expiresOn ?? Date().addingTimeInterval(3600),
            tokenType:    "Bearer",
            scope:        result.scopes.joined(separator: " ")
        )
    }

    private func presentingViewController() throws -> UIViewController {
        let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        guard let root = windowScene?.keyWindow?.rootViewController else {
            throw AuthError.invalidURL
        }
        // Walk to the topmost presented controller
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }

    private func isCancelledError(_ error: NSError) -> Bool {
        error.domain == MSALErrorDomain &&
        error.code   == MSALError.userCanceled.rawValue
    }
}
