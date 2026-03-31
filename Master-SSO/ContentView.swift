//
//  ContentView.swift
//  Master-SSO
//
//  Root view that routes to LoginView or DashboardView based on AuthManager state.
//  State transitions are logged for diagnostics.
//

import SwiftUI
import os

struct ContentView: View {

    @EnvironmentObject private var authManager: AuthManager

    private let logger = AppLogger.general

    var body: some View {
        Group {
            switch authManager.authState {
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
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .onChange(of: authManager.authState) { oldState, newState in
            logger.info("Auth state: \(String(describing: oldState)) → \(String(describing: newState))")
        }
    }
}
