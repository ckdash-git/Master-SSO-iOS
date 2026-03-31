//
//  GoogleAuthManager.swift
//  Master-SSO
//
//  Manages Google Sign-In via the GoogleSignIn SDK.
//
//  SSO behaviour:
//  Google apps (Gmail, Meet, Drive, Calendar) share authentication through
//  Google's own account system on the device. Once the user signs in here,
//  opening any Google app that uses the same account will not require
//  another sign-in — Google handles cross-app token sharing internally.
//
//  Unlike MSAL, Google Sign-In does not use a broker app. The SDK stores
//  credentials in the app's own keychain and separately in the OS-level
//  Google Account, which all Google apps respect.
//

import Combine
import GoogleSignIn
import os
import SwiftUI

@MainActor
final class GoogleAuthManager: ObservableObject {

    static let shared = GoogleAuthManager()

    // MARK: - State

    enum AuthState: Equatable {
        case unauthenticated
        case authenticating
        case authenticated(email: String, name: String)
        case failed(String)
    }

    @Published var authState: AuthState = .unauthenticated

    // MARK: - Private

    private let logger = AppLogger.auth

    private init() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: AppConfig.googleClientId
        )
    }

    // MARK: - Public API

    /// Attempts to restore a previous Google sign-in silently.
    /// Call once at app startup before showing the dashboard.
    func restoreSignIn() async {
        do {
            try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            updateState(from: GIDSignIn.sharedInstance.currentUser)
            logger.info("Google sign-in restored: \(self.userEmail ?? "unknown")")
        } catch {
            logger.info("No previous Google sign-in to restore")
            authState = .unauthenticated
        }
    }

    /// Presents the Google Sign-In flow interactively.
    func signIn() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            logger.error("Google sign-in: no root view controller found")
            authState = .failed("No root view controller")
            return
        }

        authState = .authenticating
        logger.info("Google sign-in flow started")

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            updateState(from: result.user)
            logger.info("Google sign-in succeeded: \(self.userEmail ?? "unknown")")
        } catch {
            let nsError = error as NSError
            // GIDSignInError.canceled = -5; treat as a no-op rather than a failure.
            if nsError.code == GIDSignInError.canceled.rawValue {
                logger.info("Google sign-in cancelled by user")
                authState = .unauthenticated
            } else {
                logger.error("Google sign-in failed: \(error.localizedDescription)")
                authState = .failed(error.localizedDescription)
            }
        }
    }

    /// Signs out and clears the local Google credential.
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        authState = .unauthenticated
        logger.info("Google sign-out complete")
    }

    /// Must be called from the app's onOpenURL handler so the SDK can
    /// receive the OAuth callback after the browser redirect.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - Helpers

    var userEmail: String? {
        guard case .authenticated(let email, _) = authState else { return nil }
        return email
    }

    var userName: String? {
        guard case .authenticated(_, let name) = authState else { return nil }
        return name
    }

    var isAuthenticated: Bool {
        if case .authenticated = authState { return true }
        return false
    }

    // MARK: - Private

    private func updateState(from user: GIDGoogleUser?) {
        guard let user else {
            authState = .unauthenticated
            return
        }
        authState = .authenticated(
            email: user.profile?.email ?? "",
            name: user.profile?.name ?? ""
        )
    }
}
