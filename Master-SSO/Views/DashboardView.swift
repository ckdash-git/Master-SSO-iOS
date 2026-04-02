//
//  DashboardView.swift
//  Master-SSO
//
//  Shown after successful IdP authentication. Displays the user's unified identity
//  (from the Casdoor IdP token) and one-tap launch buttons for all Microsoft and
//  Google Workspace apps.
//
//  SSO behaviour:
//  - Microsoft apps  — login hint + tenant passed via URL scheme; MSAL broker
//                      (if Authenticator is installed) provides silent SSO.
//  - Google apps     — the IdP federation establishes a shared Safari session;
//                      Google apps reuse that session automatically.
//  - Optional Google SDK login is still available for users who want an explicit
//                      Google account linked for better app-level SSO.
//

import SwiftUI

struct DashboardView: View {

    @EnvironmentObject private var idpAuthManager:    IdPAuthManager
    @EnvironmentObject private var googleAuthManager: GoogleAuthManager

    private var token: AuthToken? { idpAuthManager.currentToken }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // ── Identity card (from IdP token) ───────────────────
                    IdentityCard(
                        identifier: token?.displayIdentifier ?? "Organisation Account",
                        provider:   "Organisation SSO",
                        iconName:   "building.2.crop.circle.fill",
                        tint:       .blue
                    )
                    .padding(.top, 8)

                    Divider().padding(.horizontal)

                    // ── Microsoft apps ───────────────────────────────────
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Microsoft Apps")

                        AppLaunchButton(
                            title:    "Microsoft Teams",
                            subtitle: "Meetings, chat & collaboration",
                            iconName: "video.fill",
                            tint:     .purple
                        ) {
                            AppLauncher.shared.openTeams(
                                loginHint: token?.userEmail,
                                tenantId:  AppConfig.tenantId
                            )
                        }

                        AppLaunchButton(
                            title:    "Microsoft Outlook",
                            subtitle: "Email, calendar & contacts",
                            iconName: "envelope.fill",
                            tint:     .blue
                        ) {
                            AppLauncher.shared.openOutlook(loginHint: token?.userEmail)
                        }
                    }

                    Divider().padding(.horizontal)

                    // ── Google Workspace apps ────────────────────────────
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Google Workspace")

                        AppLaunchButton(
                            title:    "Gmail",
                            subtitle: "Google email",
                            iconName: "envelope.fill",
                            tint:     Color(red: 0.84, green: 0.24, blue: 0.19)
                        ) {
                            AppLauncher.shared.openGmail(loginHint: token?.userEmail)
                        }

                        AppLaunchButton(
                            title:    "Google Meet",
                            subtitle: "Video meetings",
                            iconName: "video.fill",
                            tint:     Color(red: 0.0, green: 0.69, blue: 0.31)
                        ) {
                            AppLauncher.shared.openGoogleMeet()
                        }

                        AppLaunchButton(
                            title:    "Google Drive",
                            subtitle: "Files & storage",
                            iconName: "folder.fill",
                            tint:     Color(red: 0.25, green: 0.59, blue: 0.98)
                        ) {
                            AppLauncher.shared.openGoogleDrive()
                        }

                        AppLaunchButton(
                            title:    "Google Calendar",
                            subtitle: "Schedule & events",
                            iconName: "calendar",
                            tint:     Color(red: 0.26, green: 0.52, blue: 0.96)
                        ) {
                            AppLauncher.shared.openGoogleCalendar()
                        }

                        // Optional: explicit Google SDK sign-in for enhanced SSO
                        if case .unauthenticated = googleAuthManager.authState {
                            GoogleConnectBanner {
                                Task { await googleAuthManager.signIn(hint: token?.userEmail) }
                            }
                        }
                    }

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
                        idpAuthManager.signOut()
                        googleAuthManager.signOut()
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
    let provider:   String
    let iconName:   String
    let tint:       Color

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

private struct AppLaunchButton: View {
    let title:    String
    let subtitle: String
    let iconName: String
    let tint:     Color
    let action:   () -> Void

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

/// Shown when Google SDK is not yet signed in — lets the user explicitly link
/// their Google account for enhanced in-app Google SSO via the SDK.
private struct GoogleConnectBanner: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "g.circle.fill")
                    .foregroundStyle(Color(red: 0.84, green: 0.24, blue: 0.19))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect Google Account")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Optional — for enhanced Google app SSO")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
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
                "You are signed in via your organisation's identity provider. " +
                "Microsoft apps use your login hint and MSAL broker (if Microsoft Authenticator is installed) for silent SSO. " +
                "Google apps share authentication through the established browser session. " +
                "On MDM-managed devices, broker apps are deployed automatically."
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
