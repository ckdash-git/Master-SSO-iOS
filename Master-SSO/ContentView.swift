//
//  ContentView.swift
//  Master-SSO
//
//  Root view that routes to LoginView or DashboardView based on AuthManager state.
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var authManager: AuthManager

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
    }
}
