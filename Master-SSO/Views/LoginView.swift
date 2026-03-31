//
//  LoginView.swift
//  Master-SSO
//
//  Presents a single "Sign in with Microsoft" button that triggers the
//  federated ASWebAuthenticationSession flow via AuthManager.
//

import SwiftUI

struct LoginView: View {

    @EnvironmentObject private var authManager: AuthManager

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

                Text("Sign in with your Microsoft account\nto access Teams and Outlook")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            // ── Action area ──────────────────────────────────────────────
            VStack(spacing: 16) {
                if case .authenticating = authManager.authState {
                    ProgressView("Signing in…")
                        .progressViewStyle(.circular)
                        .padding(.vertical, 14)
                } else {
                    Button {
                        Task { await authManager.signIn() }
                    } label: {
                        Label("Sign in with Microsoft", systemImage: "person.badge.key.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.blue)
                }

                // Error banner
                if case .failed(let message) = authManager.authState {
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
