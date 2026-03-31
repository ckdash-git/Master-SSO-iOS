//
//  DashboardView.swift
//  Master-SSO
//
//  Shown after successful Microsoft authentication. Displays identity and launch
//  buttons for Microsoft and Google apps. Google sign-in is optional — the user
//  can connect their Google account to enable one-tap access to Google Workspace.
//

import SwiftUI

struct DashboardView: View {

    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var googleAuthManager: GoogleAuthManager

    private var msToken: AuthToken? {
        guard case .authenticated(let t) = authManager.authState else { return nil }
        return t
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // ── Microsoft identity card ──────────────────────────
                    IdentityCard(
                        identifier: msToken?.displayIdentifier ?? "Unknown User",
                        provider: "Microsoft",
                        iconName: "person.circle.fill",
                        tint: .blue
                    )
                    .padding(.top, 8)

                    Divider().padding(.horizontal)

                    // ── Microsoft apps ───────────────────────────────────
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Microsoft Apps")

                        AppLaunchButton(
                            title: "Microsoft Teams",
                            subtitle: "Meetings, chat & collaboration",
                            iconName: "video.fill",
                            tint: .purple
                        ) {
                            AppLauncher.shared.openTeams(
                                loginHint: msToken?.userEmail,
                                tenantId: AppConfig.tenantId
                            )
                        }

                        AppLaunchButton(
                            title: "Microsoft Outlook",
                            subtitle: "Email, calendar & contacts",
                            iconName: "envelope.fill",
                            tint: .blue
                        ) {
                            AppLauncher.shared.openOutlook(loginHint: msToken?.userEmail)
                        }
                    }

                    Divider().padding(.horizontal)

                    // ── Google section ───────────────────────────────────
                    GoogleSection()

                    // ── SSO info ─────────────────────────────────────────
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

// MARK: - Google Section

private struct GoogleSection: View {

    @EnvironmentObject private var googleAuthManager: GoogleAuthManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Google Workspace")

            switch googleAuthManager.authState {

            case .unauthenticated, .failed:
                // Show connect button
                VStack(spacing: 8) {
                    if case .failed(let message) = googleAuthManager.authState {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                    GoogleSignInButton {
                        Task { await googleAuthManager.signIn() }
                    }
                }

            case .authenticating:
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding()
                    Spacer()
                }

            case .authenticated(let email, _):
                // Identity card
                IdentityCard(
                    identifier: email,
                    provider: "Google",
                    iconName: "person.circle.fill",
                    tint: Color(red: 0.26, green: 0.52, blue: 0.96)
                )

                // Google app launch buttons
                AppLaunchButton(
                    title: "Gmail",
                    subtitle: "Google email",
                    iconName: "envelope.fill",
                    tint: Color(red: 0.84, green: 0.24, blue: 0.19)
                ) {
                    AppLauncher.shared.openGmail()
                }

                AppLaunchButton(
                    title: "Google Meet",
                    subtitle: "Video meetings",
                    iconName: "video.fill",
                    tint: Color(red: 0.0, green: 0.69, blue: 0.31)
                ) {
                    AppLauncher.shared.openGoogleMeet()
                }

                AppLaunchButton(
                    title: "Google Drive",
                    subtitle: "Files & storage",
                    iconName: "folder.fill",
                    tint: Color(red: 0.25, green: 0.59, blue: 0.98)
                ) {
                    AppLauncher.shared.openGoogleDrive()
                }

                AppLaunchButton(
                    title: "Google Calendar",
                    subtitle: "Schedule & events",
                    iconName: "calendar",
                    tint: Color(red: 0.26, green: 0.52, blue: 0.96)
                ) {
                    AppLauncher.shared.openGoogleCalendar()
                }

                // Google sign-out
                Button(role: .destructive) {
                    googleAuthManager.signOut()
                } label: {
                    Label("Disconnect Google Account", systemImage: "minus.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Sub-views

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal)
    }
}

private struct IdentityCard: View {

    let identifier: String
    let provider: String
    let iconName: String
    let tint: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 56))
                .foregroundStyle(tint)

            Text(identifier)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Label("Signed in · \(provider)", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
        .padding()
    }
}

private struct GoogleSignInButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "g.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.84, green: 0.24, blue: 0.19))
                Text("Sign in with Google")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
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
                "Microsoft SSO: Full silent SSO requires Microsoft Authenticator installed and signed in. " +
                "Google SSO: Google apps share authentication automatically — once you sign in to any " +
                "Google app, others open without re-authentication. " +
                "On MDM-managed devices, both Authenticator and Google apps are auto-deployed."
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
