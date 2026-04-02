//
//  ContentView.swift
//  Master-SSO
//
//  Root view router. Drives navigation from IdPAuthManager state — the custom
//  Casdoor IdP is the single sign-on entry point for all providers.
//

import SwiftUI
import os

struct ContentView: View {

    @EnvironmentObject private var idpAuthManager: IdPAuthManager

    private let logger = AppLogger.general

    var body: some View {
        Group {
            switch idpAuthManager.authState {
            case .unauthenticated, .failed:
                LoginView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal:   .move(edge: .leading)
                    ))
            case .authenticating:
                LoginView()
            case .authenticated:
                DashboardView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .trailing)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: idpAuthManager.isAuthenticated)
        .onChange(of: idpAuthManager.authState) { oldState, newState in
            logger.info("Auth state: \(String(describing: oldState)) → \(String(describing: newState))")
        }
    }
}
