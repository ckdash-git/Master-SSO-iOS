//
//  Master_SSOApp.swift
//  Master-SSO
//
//  App entry point. IdPAuthManager is the primary auth driver.
//  AuthManager (MSAL) and GoogleAuthManager are kept as environment objects
//  so their broker/SDK benefits are available to views that need them.
//

import GoogleSignIn
import MSAL
import SwiftUI
import os

@main
struct Master_SSOApp: App {

    @StateObject private var idpAuthManager    = IdPAuthManager.shared
    @StateObject private var authManager       = AuthManager.shared
    @StateObject private var googleAuthManager = GoogleAuthManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(idpAuthManager)
                .environmentObject(authManager)
                .environmentObject(googleAuthManager)
                .task {
                    AppLogger.general.info("Master-SSO application launched")
                    AppLauncher.shared.logInstallStatus()
                    await googleAuthManager.restoreSignIn()
                }
                .onOpenURL { url in
                    // 1. Custom IdP (Casdoor) callback — master-sso://oauth/callback
                    if url.scheme == "master-sso" { return }   // handled by ASWebAuthenticationSession

                    // 2. Google Sign-In callback
                    if googleAuthManager.handle(url) { return }

                    // 3. MSAL broker callback (Microsoft Authenticator)
                    MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
                }
        }
    }
}
