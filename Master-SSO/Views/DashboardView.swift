//
//  DashboardView.swift
//  Master-SSO
//
//  Shown after successful authentication. Displays identity, launch buttons for
//  Microsoft Teams and Microsoft Outlook, and a sign-out control.
//

import SwiftUI

struct DashboardView: View {

    @EnvironmentObject private var authManager: AuthManager

    private var token: AuthToken? {
        guard case .authenticated(let t) = authManager.authState else { return nil }
        return t
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // ── Identity card ────────────────────────────────────
                    IdentityCard(
                        identifier: token?.displayIdentifier ?? "Unknown User"
                    )
                    .padding(.top, 8)

                    Divider()
                        .padding(.horizontal)

                    // ── App launch section ───────────────────────────────
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Open Microsoft Apps")
                            .font(.headline)
                            .padding(.horizontal)

                        AppLaunchButton(
                            title: "Microsoft Teams",
                            subtitle: "Meetings, chat & collaboration",
                            iconName: "video.fill",
                            tint: .purple
                        ) {
                            AppLauncher.shared.openTeams(
                                loginHint: token?.userEmail,
                                tenantId: AppConfig.tenantId
                            )
                        }

                        AppLaunchButton(
                            title: "Microsoft Outlook",
                            subtitle: "Email, calendar & contacts",
                            iconName: "envelope.fill",
                            tint: .blue
                        ) {
                            AppLauncher.shared.openOutlook(
                                loginHint: token?.userEmail
                            )
                        }
                    }

                    // ── SSO information note ─────────────────────────────
                    SSOInfoNote()

                    Spacer(minLength: 24)
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        authManager.signOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}

// MARK: - Sub-views

private struct IdentityCard: View {

    let identifier: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text(identifier)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Label("Signed in", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
        .padding()
    }
}

private struct AppLaunchButton: View {

    let title: String
    let subtitle: String
    let iconName: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.forward.app.fill")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}

private struct SSOInfoNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("About SSO on personal iPhone", systemImage: "info.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(
                "Your account is pre-filled when opening Teams and Outlook. " +
                "If prompted to sign in, complete the Microsoft login once — " +
                "the shared browser session may allow it to complete silently. " +
                "Full silent SSO requires MDM or Microsoft Authenticator."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(.tertiary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}
