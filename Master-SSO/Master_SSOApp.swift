//
//  Master_SSOApp.swift
//  Master-SSO
//
//  App entry point. Injects AuthManager as a shared environment object so
//  every view in the hierarchy can observe authentication state changes.
//

import MSAL
import SwiftUI
import os

@main
struct Master_SSOApp: App {

    @StateObject private var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .task {
                    AppLogger.general.info("Master-SSO application launched")
                    AppLauncher.shared.logInstallStatus()
                }
                .onOpenURL { url in
                    // Forward broker callbacks (Microsoft Authenticator ↔ MSAL).
                    MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
                }
        }
    }
}
