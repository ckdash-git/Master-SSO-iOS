//
//  IdPAuthManager.swift
//  Master-SSO
//
//  Authenticates via the organisation's custom Casdoor IdP using OIDC Authorization
//  Code flow with PKCE (RFC-7636, S256).
//
//  The IdP page presents all configured identity providers (Microsoft, Google, …)
//  so the user picks their federation target without the app needing to implement
//  separate per-provider flows.
//
//  Redirect URI registered in Casdoor:  master-sso://oauth/callback
//  CFBundleURLSchemes in Info.plist:     master-sso
//
//  Security note:
//  client_secret is included because Casdoor requires it even for native apps by
//  default.  For production, configure the application in Casdoor as a "public"
//  client so the secret is no longer required, removing it from the binary.
//

import AuthenticationServices
import Combine
import Foundation
import os
import UIKit

@MainActor
final class IdPAuthManager: NSObject, ObservableObject {

    static let shared = IdPAuthManager()

    // MARK: - Auth state

    enum AuthState: Equatable {
        case unauthenticated
        case authenticating
        case authenticated(AuthToken)
        case failed(String)

        static func == (lhs: AuthState, rhs: AuthState) -> Bool {
            switch (lhs, rhs) {
            case (.unauthenticated, .unauthenticated): return true
            case (.authenticating,  .authenticating):  return true
            case (.authenticated(let a), .authenticated(let b)): return a == b
            case (.failed(let a),        .failed(let b)):        return a == b
            default: return false
            }
        }
    }

    @Published var authState: AuthState = .unauthenticated

    var isAuthenticated: Bool {
        if case .authenticated = authState { return true }
        return false
    }

    var currentToken: AuthToken? {
        guard case .authenticated(let token) = authState else { return nil }
        return token
    }

    // MARK: - Private

    private let logger = AppLogger.auth
    private let keychainKey = "idp_auth_token"
    private var authSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
        restoreSession()
    }

    // MARK: - Session restore

    private func restoreSession() {
        do {
            let data  = try KeychainService.shared.load(forKey: keychainKey)
            let token = try JSONDecoder().decode(AuthToken.self, from: data)
            if token.isExpired {
                logger.info("IdP token expired — clearing, presenting login")
                KeychainService.shared.delete(forKey: keychainKey)
            } else {
                let id = token.displayIdentifier ?? "unknown"
                logger.info("IdP session restored — user: \(id)")
                authState = .authenticated(token)
            }
        } catch KeychainError.itemNotFound {
            logger.info("No IdP token in Keychain — presenting login")
        } catch {
            logger.error("Session restore error: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign in

    func signIn() async {
        guard authState != .authenticating else { return }
        authState = .authenticating
        logger.info("IdP auth flow started")

        do {
            let pkce     = try PKCEHelper.generate()
            let state    = randomState()
            let authURL  = try buildAuthURL(pkce: pkce, state: state)
            let callback = try await openAuthSession(url: authURL)
            let code     = try extractCode(from: callback, expectedState: state)
            let token    = try await exchangeCode(code, pkce: pkce)

            try KeychainService.shared.save(JSONEncoder().encode(token), forKey: keychainKey)
            let id = token.displayIdentifier ?? "unknown"
            logger.info("IdP sign-in succeeded — user: \(id)")
            authState = .authenticated(token)

        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            logger.info("IdP sign-in cancelled by user")
            authState = .unauthenticated

        } catch {
            logger.error("IdP sign-in failed: \(error.localizedDescription)")
            authState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Sign out

    func signOut() {
        logger.info("IdP sign-out — clearing token")
        KeychainService.shared.delete(forKey: keychainKey)
        authState = .unauthenticated
    }

    // MARK: - Build authorization URL

    private func buildAuthURL(pkce: PKCEParams, state: String) throws -> URL {
        var components = URLComponents(string: AppConfig.idpAuthorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id",             value: AppConfig.idpClientId),
            URLQueryItem(name: "response_type",         value: "code"),
            URLQueryItem(name: "redirect_uri",          value: AppConfig.idpRedirectURI),
            URLQueryItem(name: "scope",                 value: "openid profile email offline_access"),
            URLQueryItem(name: "code_challenge",        value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state",                 value: state),
        ]
        guard let url = components.url else { throw AuthError.invalidURL }
        logger.info("IdP auth URL built — endpoint: \(AppConfig.idpAuthorizationEndpoint)")
        return url
    }

    // MARK: - Launch ASWebAuthenticationSession

    private func openAuthSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "master-sso"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: AuthError.invalidCallback)
                }
            }
            // false = share Safari session, enabling SSO for Microsoft + Google apps
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self
            session.start()
            self.authSession = session  // retain to prevent premature deallocation
        }
    }

    // MARK: - Extract authorization code

    private func extractCode(from url: URL, expectedState: String) throws -> String {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let items = components.queryItems
        else { throw AuthError.invalidCallback }

        // CSRF protection — verify state
        if let returnedState = items.first(where: { $0.name == "state" })?.value,
           returnedState != expectedState {
            logger.warning("State mismatch in IdP callback — possible CSRF")
            throw AuthError.authorizationFailed("State parameter mismatch")
        }

        if let error = items.first(where: { $0.name == "error" })?.value {
            let desc = items.first(where: { $0.name == "error_description" })?.value ?? error
            logger.error("IdP returned error: \(desc)")
            throw AuthError.authorizationFailed(desc)
        }

        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw AuthError.authorizationFailed("Authorization code missing from callback")
        }
        return code
    }

    // MARK: - Token exchange

    private func exchangeCode(_ code: String, pkce: PKCEParams) async throws -> AuthToken {
        guard let url = URL(string: AppConfig.idpTokenEndpoint) else { throw AuthError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let fields: [(String, String)] = [
            ("grant_type",    "authorization_code"),
            ("client_id",     AppConfig.idpClientId),
            ("client_secret", AppConfig.idpClientSecret),
            ("code",          code),
            ("code_verifier", pkce.verifier),
            ("redirect_uri",  AppConfig.idpRedirectURI),
        ]
        request.httpBody = fields
            .map { "\($0.0)=\($0.1.percentEncoded)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("Token exchange HTTP error: \(statusCode)")
            throw AuthError.tokenExchangeFailed(statusCode: statusCode, body: body)
        }

        let dto = try JSONDecoder().decode(IdPTokenResponse.self, from: data)
        logger.info("Token exchange succeeded — token_type: \(dto.tokenType)")

        return AuthToken(
            idToken:      dto.idToken      ?? "",
            accessToken:  dto.accessToken,
            refreshToken: dto.refreshToken,
            expiresAt:    Date().addingTimeInterval(TimeInterval(dto.expiresIn ?? 3600)),
            tokenType:    dto.tokenType,
            scope:        dto.scope        ?? ""
        )
    }

    // MARK: - Helpers

    private func randomState() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension IdPAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }
}

// MARK: - Token response DTO

private struct IdPTokenResponse: Decodable {
    let accessToken:  String
    let idToken:      String?
    let refreshToken: String?
    let expiresIn:    Int?
    let tokenType:    String
    let scope:        String?

    private enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case idToken      = "id_token"
        case refreshToken = "refresh_token"
        case expiresIn    = "expires_in"
        case tokenType    = "token_type"
        case scope        = "scope"
    }
}

// MARK: - URL encoding helper

private extension String {
    var percentEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
