//
//  Master_SSOApp.swift
//  Master-SSO
//
//  App entry point. Injects AuthManager and GoogleAuthManager as shared environment
//  objects so every view in the hierarchy can observe authentication state changes.
//

import GoogleSignIn
import MSAL
import SwiftUI
import os

@main
struct Master_SSOApp: App {

    @StateObject private var authManager = AuthManager.shared
    @StateObject private var googleAuthManager = GoogleAuthManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(googleAuthManager)
                .task {
                    AppLogger.general.info("Master-SSO application launched")
                    AppLauncher.shared.logInstallStatus()
                    // Attempt to restore a previous Google sign-in silently.
                    await googleAuthManager.restoreSignIn()
                }
                .onOpenURL { url in
                    // Google Sign-In OAuth callback must be checked first.
                    if googleAuthManager.handle(url) { return }
                    // Forward remaining broker callbacks to MSAL (Microsoft Authenticator).
                    MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
                }
        }
    }
}
