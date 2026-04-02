//
//  LoginView.swift
//  Master-SSO
//
//  Single sign-in entry point. Tapping "Sign in" opens the organisation's Casdoor
//  IdP page, which presents all configured identity providers (Microsoft, Google, …).
//  The user picks their provider; federation and token exchange happen server-side.
//

import SwiftUI

struct LoginView: View {

    @EnvironmentObject private var idpAuthManager: IdPAuthManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Header ───────────────────────────────────────────────────
            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)

                Text("Master SSO")
                    .font(.largeTitle.bold())

                Text("Sign in with your organisation account\nto access Microsoft and Google Workspace apps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            // ── Action area ──────────────────────────────────────────────
            VStack(spacing: 16) {
                if case .authenticating = idpAuthManager.authState {
                    ProgressView("Signing in…")
                        .progressViewStyle(.circular)
                        .padding(.vertical, 14)
                } else {
                    Button {
                        Task { await idpAuthManager.signIn() }
                    } label: {
                        Label("Sign in", systemImage: "person.badge.key.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.blue)
                }

                // Provider hint
                if case .unauthenticated = idpAuthManager.authState {
                    HStack(spacing: 8) {
                        Image(systemName: "building.2")
                            .foregroundStyle(.secondary)
                        Text("You will be redirected to your organisation's login page")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                // Error banner
                if case .failed(let message) = idpAuthManager.authState {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}
