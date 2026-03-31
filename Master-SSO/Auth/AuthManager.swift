//
//  AuthManager.swift
//  Master-SSO
//
//  Orchestrates the full PKCE + ASWebAuthenticationSession login flow.
//
//  Flow:
//    1. Build Microsoft authorization URL with PKCE challenge.
//    2. Open ASWebAuthenticationSession (system browser — shares Safari cookies).
//    3. Receive redirect to master-sso://auth/callback?code=...
//    4. Exchange the code + PKCE verifier for tokens at the token endpoint.
//    5. Persist tokens in Keychain via TokenManager.
//
//  prefersEphemeralWebBrowserSession is intentionally set to FALSE so that
//  the system browser session (and its cookies) is shared with Safari,
//  enabling best-effort SSO when the user later opens Teams or Outlook.
//

import AuthenticationServices
import Foundation
import UIKit

@MainActor
final class AuthManager: NSObject, ObservableObject {

    static let shared = AuthManager()

    // MARK: - Published state

    enum AuthState: Equatable {
        case unauthenticated
        case authenticating
        case authenticated(AuthToken)
        case failed(String)          // error description for UI display

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
    private var activeSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
        restoreSessionIfValid()
    }

    // MARK: - Public API

    /// Starts the federated sign-in flow via ASWebAuthenticationSession.
    /// Safe to call from a SwiftUI button; guards against concurrent invocations.
    func signIn() async {
        // Prevent duplicate concurrent auth flows.
        guard authState != .authenticating else {
            logger.warning("Sign-in already in progress — ignoring duplicate call")
            return
        }
        logger.info("Auth flow started")
        authState = .authenticating

        do {
            let pkce        = try PKCEHelper.generate()
            let authURL     = try buildAuthorizationURL(pkce: pkce)
            let callbackURL = try await presentAuthSession(url: authURL)
            let code        = try extractAuthCode(from: callbackURL)
            let token       = try await exchangeCodeForTokens(code: code, pkce: pkce)
            try TokenManager.shared.save(token: token)
            authState = .authenticated(token)
            logger.info("Auth flow completed — user signed in")
        } catch AuthError.userCancelled {
            // Cancellation is a normal user action, not an error.
            logger.info("Sign-in cancelled by user — returning to unauthenticated state")
            authState = .unauthenticated
        } catch let error as AuthError {
            let description = error.errorDescription ?? error.localizedDescription
            logger.error("Auth flow failed: \(description)")
            authState = .failed(description)
        } catch {
            logger.error("Auth flow unexpected error: \(error.localizedDescription)")
            authState = .failed(error.localizedDescription)
        }
    }

    /// Cancels an in-progress ASWebAuthenticationSession programmatically.
    func cancelSignIn() {
        guard case .authenticating = authState else { return }
        activeSession?.cancel()
        activeSession = nil
        authState = .unauthenticated
        logger.info("Sign-in cancelled programmatically")
    }

    /// Clears the local session. Optionally initiates IdP front-channel logout.
    func signOut() {
        logger.info("Sign-out initiated")
        TokenManager.shared.deleteAll()
        authState = .unauthenticated
        logger.info("Sign-out complete — session cleared")
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

    // MARK: - Authorization URL

    private func buildAuthorizationURL(pkce: PKCEParams) throws -> URL {
        var components = URLComponents(string: AppConfig.authorizationEndpoint)
        components?.queryItems = [
            URLQueryItem(name: "client_id",             value: AppConfig.clientId),
            URLQueryItem(name: "response_type",         value: "code"),
            URLQueryItem(name: "redirect_uri",          value: AppConfig.redirectURI),
            URLQueryItem(name: "scope",                 value: AppConfig.scopes),
            URLQueryItem(name: "code_challenge",        value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "response_mode",         value: "query"),
        ]
        guard let url = components?.url else {
            throw AuthError.invalidURL
        }
        logger.debug("Authorization URL constructed")
        return url
    }

    // MARK: - ASWebAuthenticationSession

    private func presentAuthSession(url: URL) async throws -> URL {
        logger.info("Opening ASWebAuthenticationSession")
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "master-sso"
            ) { [weak self] callbackURL, error in
                guard let self else { return }
                if let error {
                    let asError = error as? ASWebAuthenticationSessionError
                    if asError?.code == .canceledLogin {
                        self.logger.info("User cancelled sign-in")
                        continuation.resume(throwing: AuthError.userCancelled)
                    } else {
                        self.logger.error("Session error: \(error.localizedDescription)")
                        continuation.resume(throwing: AuthError.sessionError(error))
                    }
                    return
                }
                guard let callbackURL else {
                    self.logger.error("Callback URL was nil")
                    continuation.resume(throwing: AuthError.invalidCallback)
                    return
                }
                self.logger.info("Redirect received from authorization server")
                continuation.resume(returning: callbackURL)
            }
            // Share the existing Safari browser session so Microsoft apps can
            // inherit the authenticated cookie — best-effort SSO without a broker.
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self
            activeSession = session
            session.start()
        }
    }

    // MARK: - Code extraction

    private func extractAuthCode(from callbackURL: URL) throws -> String {
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []

        if let errorParam = items.first(where: { $0.name == "error" })?.value {
            let description = items.first(where: { $0.name == "error_description" })?.value ?? ""
            throw AuthError.authorizationFailed("\(errorParam): \(description)")
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw AuthError.invalidCallback
        }
        logger.debug("Authorization code extracted from callback")
        return code
    }

    // MARK: - Token exchange

    private func exchangeCodeForTokens(code: String, pkce: PKCEParams) async throws -> AuthToken {
        logger.info("Exchanging authorization code for tokens")
        guard let url = URL(string: AppConfig.tokenEndpoint) else {
            throw AuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type":    "authorization_code",
            "client_id":     AppConfig.clientId,
            "code":          code,
            "redirect_uri":  AppConfig.redirectURI,
            "code_verifier": pkce.verifier,
        ]
        request.httpBody = body
            .map { "\($0.key)=\($0.value.urlQueryEncoded)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.tokenExchangeFailed(statusCode: 0, body: "No HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("Token exchange HTTP \(http.statusCode): \(body)")
            throw AuthError.tokenExchangeFailed(statusCode: http.statusCode, body: body)
        }

        do {
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            logger.info("Tokens received and decoded")
            return tokenResponse.toAuthToken()
        } catch {
            logger.error("Token decoding failed: \(error.localizedDescription)")
            throw AuthError.tokenDecodingFailed
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(
        for session: ASWebAuthenticationSession
    ) -> ASPresentationAnchor {
        // Protocol requires nonisolated; Apple guarantees this is called on the main
        // thread, so assumeIsolated is safe here.
        MainActor.assumeIsolated {
            let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            return windowScene?.keyWindow ?? ASPresentationAnchor()
        }
    }
}

// MARK: - String helpers

private extension String {
    var urlQueryEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
