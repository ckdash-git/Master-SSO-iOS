# Master-SSO — iOS Federated Microsoft SSO

A native iOS application that authenticates users against **Azure Active Directory** using **MSAL (Microsoft Authentication Library)** with **Microsoft Authenticator broker support**, enabling true silent cross-app Single Sign-On to Microsoft Teams and Outlook on a personal (non-MDM) iPhone.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Project Structure](#project-structure)
4. [Prerequisites](#prerequisites)
5. [Azure AD Portal Setup](#azure-ad-portal-setup)
6. [Project Configuration](#project-configuration)
7. [How SSO Works](#how-sso-works)
8. [Module Breakdown](#module-breakdown)
9. [Build & Run](#build--run)
10. [Issues Encountered & Fixes](#issues-encountered--fixes)
11. [Troubleshooting](#troubleshooting)
12. [Known Limitations](#known-limitations)

---

## Overview

| Property | Value |
|---|---|
| Platform | iOS 18.6+ |
| Language | Swift 5.10 |
| Auth Library | MSAL for iOS 1.9.0 |
| Bundle ID | `com.cachatto.Master-SSO` |
| Redirect URI | `msauth.com.cachatto.Master-SSO://auth` |
| Auth Flow | MSAL Interactive → Broker (Microsoft Authenticator) → Silent |
| Token Storage | System Keychain, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| Target Apps | Microsoft Teams, Microsoft Outlook |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Master-SSO App                        │
│                                                         │
│  ContentView → LoginView / DashboardView                │
│       │                    │                            │
│  AuthManager (MSAL)   AppLauncher (deep links)         │
│       │                    │                            │
│  MSALPublicClientApp  msteams:// / ms-outlook://        │
│       │                                                 │
│  Keychain (TokenManager + KeychainService)              │
└────────────────────┬────────────────────────────────────┘
                     │  broker IPC
                     ▼
          ┌──────────────────────┐
          │  Microsoft           │
          │  Authenticator       │  ← shared token cache
          │  (broker)            │     accessible to Teams,
          └──────────────────────┘     Outlook, our app
                     │
                     ▼
          ┌──────────────────────┐
          │  Azure Active        │
          │  Directory (Entra)   │
          └──────────────────────┘
```

**Without broker** (Authenticator not installed): MSAL falls back to ASWebAuthenticationSession using shared Safari cookies — Teams/Outlook will still require separate sign-in.

**With broker** (Authenticator installed and signed in): tokens are deposited into the shared broker cache; Teams and Outlook obtain them silently with no re-login prompt.

---

## Project Structure

```
Master-SSO-iOS/
├── Master-SSO.xcodeproj/
│   └── project.pbxproj
├── Master-SSO/
│   ├── Master_SSOApp.swift          # @main, onOpenURL for MSAL callback
│   ├── ContentView.swift            # Root router (Login / Dashboard)
│   ├── Info.plist                   # URL schemes, LSApplicationQueriesSchemes
│   ├── Master-SSO.entitlements      # keychain-access-groups
│   ├── Config/
│   │   └── AppConfig.swift          # Client ID, tenant, scopes, redirect URI
│   ├── Logging/
│   │   └── AppLogger.swift          # os.Logger instances by category
│   ├── Auth/
│   │   ├── AuthManager.swift        # MSAL sign-in/sign-out, broker config
│   │   ├── AuthError.swift          # Typed error enum
│   │   └── PKCEHelper.swift         # RFC-7636 (unused with MSAL, kept for reference)
│   ├── Models/
│   │   ├── AuthToken.swift          # Codable token struct + JWT computed props
│   │   ├── TokenResponse.swift      # Decodable DTO from token endpoint
│   │   └── JWTParser.swift          # Base64URL payload decoder (display only)
│   ├── Token/
│   │   ├── KeychainService.swift    # Security.framework wrapper
│   │   └── TokenManager.swift      # JSON-encode AuthToken to/from Keychain
│   ├── Launch/
│   │   └── AppLauncher.swift        # Deep-link Teams/Outlook with login hints
│   └── Views/
│       ├── LoginView.swift          # Sign-in button, loading state, error banner
│       └── DashboardView.swift      # Identity card, launch buttons, sign-out
└── README.md
```

---

## Prerequisites

### Device
- Physical iPhone running iOS 18.6+ (broker does **not** work on the Simulator)
- **Microsoft Authenticator** installed from the App Store and signed in with the work/school account

### Developer
- Xcode 16+
- Apple Developer account (paid or free — Automatic signing handles provisioning)
- Access to the Azure AD (Entra ID) tenant you are authenticating against

### Microsoft 365
- The sign-in account must have a **Teams license** assigned in the Microsoft 365 Admin Center; without it, Teams opens but shows a license error
- The account must be a **member of the Teams organisation** to open direct team links

---

## Azure AD Portal Setup

### 1. App Registration

1. Go to [portal.azure.com](https://portal.azure.com) → **Azure Active Directory** → **App registrations** → **New registration**
2. Name: `SSO-iOS` (or any name)
3. Supported account types: **Single tenant** (your organisation only)
4. Redirect URI: leave blank for now, add it in the next step

### 2. Add iOS/macOS Platform (critical)

1. Open the App Registration → **Authentication** → **Add a platform** → **iOS / macOS**
2. Bundle ID: `com.cachatto.Master-SSO`
3. Azure generates the redirect URI automatically: `msauth.com.cachatto.Master-SSO://auth`
4. Save

Without this step MSAL fails immediately with `MSALErrorDomain -50000`.

### 3. API Permissions

1. **Authentication** tab → verify `User.Read` (Microsoft Graph) is listed
2. If absent: **API permissions** → **Add a permission** → **Microsoft Graph** → **Delegated** → `User.Read`
3. Grant admin consent if required by your tenant policy

### 4. Note Your Credentials

| Field | Where to find |
|---|---|
| Application (client) ID | App Registration → Overview |
| Directory (tenant) ID | App Registration → Overview |

---

## Project Configuration

### `AppConfig.swift`

```swift
enum AppConfig {
    static let clientId  = "YOUR_CLIENT_ID"       // Application ID from Azure
    static let tenantId  = "YOUR_TENANT_ID"        // Directory ID from Azure
    static let redirectURI = "msauth.com.cachatto.Master-SSO://auth"
    // MSAL automatically adds openid, profile, offline_access — do NOT include them.
    static let scopes: [String] = ["User.Read"]
    static var authorityURL: URL {
        URL(string: "https://login.microsoftonline.com/\(tenantId)")!
    }
}
```

### `Info.plist` — required entries

```xml
<!-- MSAL broker redirect scheme -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>msauth.com.cachatto.Master-SSO</string>
        </array>
    </dict>
</array>

<!-- Apps that can be launched via deep link -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>msteams</string>
    <string>ms-outlook</string>
    <string>msauthv2</string>
    <string>msauthv3</string>
</array>
```

### `Master-SSO.entitlements` — required for broker

```xml
<key>keychain-access-groups</key>
<array>
    <!-- MSAL broker stores its cryptographic key in this shared group.       -->
    <!-- Must match config.cacheConfig.keychainSharingGroup in AuthManager.   -->
    <string>$(AppIdentifierPrefix)com.microsoft.adalcache</string>
</array>
```

### `AuthManager.swift` — MSAL setup (excerpt)

```swift
let config = MSALPublicClientApplicationConfig(
    clientId: AppConfig.clientId,
    redirectUri: AppConfig.redirectURI,
    authority: authority
)
// Must match the keychain-access-groups entitlement entry.
config.cacheConfig.keychainSharingGroup = "com.microsoft.adalcache"
```

---

## How SSO Works

### Sign-in flow

```
1. App calls AuthManager.signIn()
2. MSAL checks whether Microsoft Authenticator is installed (msauthv3://)
   ├── YES → switches to Authenticator (broker IPC)
   │          user confirms in Authenticator
   │          Authenticator deposits token in com.microsoft.adalcache
   │          Teams + Outlook can now get tokens silently
   └── NO  → opens ASWebAuthenticationSession (Safari)
              user signs in via browser
              token stored in app-local Keychain
              Teams/Outlook get login hint via URL scheme but must re-auth
3. Token returned → stored in Keychain via TokenManager
4. AuthState transitions: unauthenticated → authenticating → authenticated
```

### Launch Teams / Outlook

```
DashboardView taps "Open Teams"
└── AppLauncher.openTeams(loginHint: email, tenantId: tenantId)
    └── msteams://?tenantId=<id>&loginhint=<email>
        ├── broker present  → Teams silently gets a token, opens directly
        └── no broker       → Teams pre-fills the sign-in screen with the hint
```

### Silent token refresh

- MSAL handles refresh tokens automatically
- `TokenManager.hasValidToken` checks expiry; expired tokens trigger `signIn()` on next launch
- The MSAL cache in `com.microsoft.adalcache` is shared with the broker, so silent refresh works across app restarts

---

## Module Breakdown

### `AuthManager` (`Auth/AuthManager.swift`)
`@MainActor ObservableObject`. Owns the `MSALPublicClientApplication` instance. Exposes:
- `signIn() async` — interactive login via MSAL with `webviewType = .default` (enables broker)
- `signOut()` — removes all MSAL accounts, clears Keychain
- `authState: AuthState` — `@Published` enum driving the root view router

### `TokenManager` (`Token/TokenManager.swift`)
JSON-encodes `AuthToken` into the Keychain via `KeychainService`. Provides `hasValidToken`, `loadToken()`, `save(token:)`, `deleteAll()`.

### `KeychainService` (`Token/KeychainService.swift`)
Thin `Security.framework` wrapper using `kSecClassGenericPassword` + `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. No third-party dependency.

### `AuthToken` (`Models/AuthToken.swift`)
`Codable, Equatable` struct. Contains `idToken`, `accessToken`, `refreshToken`, `expiresAt`. Computed properties `userEmail`, `userName`, `displayIdentifier` parse the JWT payload via `JWTParser` (display only — no signature verification).

### `AppLauncher` (`Launch/AppLauncher.swift`)
Constructs deep-link URLs for Teams (`msteams://`) and Outlook (`ms-outlook://`) with `loginHint` / `tenantId` query parameters. Checks install status with `canOpenURL` and logs via `AppLogger.launch`.

### `AppLogger` (`Logging/AppLogger.swift`)
Centralised `os.Logger` instances: `.auth`, `.token`, `.launch`, `.general`. All subsystems use `Bundle.main.bundleIdentifier`.

---

## Build & Run

```bash
# Clone
git clone <repo>
cd Master-SSO-iOS

# Open in Xcode (let it resolve the MSAL Swift Package automatically)
open Master-SSO.xcodeproj

# Select your physical iPhone as the destination
# Product → Run (⌘R)
```

**MSAL Swift Package:** Added via Swift Package Manager — `https://github.com/AzureAD/microsoft-authentication-library-for-objc`, version `1.9.0` (upToNextMajorVersion from 1.5.0). Xcode resolves it automatically on first build.

**Required before first run:**
1. In `AppConfig.swift`, set your real `clientId` and `tenantId`
2. Complete the [Azure AD Portal Setup](#azure-ad-portal-setup) steps
3. Install Microsoft Authenticator on the device and sign in once with the work account

---

## Issues Encountered & Fixes

### 1. AADSTS900023 — invalid tenant identifier
**Cause:** Placeholder strings `"YOUR_AZURE_APP_CLIENT_ID"` and `"YOUR_TENANT_ID_OR_common"` left in `AppConfig.swift`.
**Fix:** Replace with real Application ID and Directory ID from Azure portal.

---

### 2. 64 build errors — SE-0357 transitive import visibility
**Cause:** `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` disables transitive re-exports. Every file must explicitly import every module it directly uses.
**Fix:** Added missing explicit imports:
- `AppLogger.swift` → `import Foundation` (for `Bundle.main.bundleIdentifier`)
- `AuthManager.swift` → `import Combine` (for `ObservableObject`, `@Published`) + `import os`
- `AppLauncher.swift` → `import os`

---

### 3. "Multiple commands produce Info.plist"
**Cause:** `PBXFileSystemSynchronizedRootGroup` (Xcode 16 feature) auto-includes all files in the directory into build phases, so `Info.plist` was being processed twice — once by `INFOPLIST_FILE` and once by Copy Bundle Resources.
**Fix:** Added `PBXFileSystemSynchronizedBuildFileExceptionSet` with `membershipExceptions = (Info.plist)` in `project.pbxproj`.

---

### 4. MSALErrorInternal -42000 — reserved scopes
**Cause:** `AppConfig.scopes` included `"openid"`, `"profile"`, `"offline_access"`. MSAL adds these automatically; specifying them explicitly throws an internal error.
**Fix:** Changed scopes to `["User.Read"]` only.

---

### 5. MSALErrorInternal -42708 / errSecMissingEntitlement (-34018) — broker key failure
**Cause (first attempt):** Entitlements file declared `$(AppIdentifierPrefix)com.cachatto.Master-SSO` but MSAL's broker stores its cryptographic key in `com.microsoft.adalcache`. The two groups didn't match so iOS denied access.
**Fix:**
- `Master-SSO.entitlements` → `$(AppIdentifierPrefix)com.microsoft.adalcache`
- `AuthManager.setupMSAL()` → `config.cacheConfig.keychainSharingGroup = "com.microsoft.adalcache"`
- Delete app from device and clean-install (stale keychain data from wrong group causes residual errors)

---

### 6. Teams / Outlook still prompted for login after app auth (no broker)
**Cause:** Without the Microsoft Authenticator broker, each app has its own isolated token cache. Shared Safari cookies are best-effort only.
**Mitigation (partial):** `AppLauncher` passes `loginHint` / `tenantId` in the URL scheme so Teams/Outlook pre-fills the account.
**Full fix:** Install Microsoft Authenticator and sign in once — broker deposits tokens in the shared cache, Teams/Outlook fetch them silently.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `MSALErrorDomain -50000 sub -42000` | Reserved scopes in `acquireToken` call | Use only `["User.Read"]` in `AppConfig.scopes` |
| `MSALErrorDomain -50000 sub -42708` / `-34018` | Wrong keychain access group in entitlements | Set group to `com.microsoft.adalcache` in both entitlements and MSAL config |
| "License not assigned" in Teams | User account has no Teams license | Admin must assign a Microsoft 365 license in M365 Admin Center |
| "Cannot open the link" in Teams | Account not a member of that Teams organisation | Admin must invite the user to the Teams org |
| Teams/Outlook still asks for login | Microsoft Authenticator not installed or not signed in | Install Authenticator, sign in once with the work account |
| No auth UI appears | Running on Simulator (broker not available) | Test on a physical device |
| Auth fails after updating entitlements | Stale installation | Delete app from device, clean build (`Shift+Cmd+K`), reinstall |

---

## Known Limitations

- **No MDM required** — this is an intentional design goal. The app achieves SSO without MDM by using the Microsoft Authenticator broker as the shared credential store.
- **Authenticator must be installed by the user** — iOS does not allow apps to install other apps, and MDM is the only mechanism that can push Authenticator silently.
- **Simulator support** — MSAL broker is unavailable on the Simulator. Auth falls back to the browser; test full broker SSO on a real device only.
- **Teams organisation membership** — the SSO app authenticates the user to Azure AD, but Teams additionally requires the user to be a member of the specific Teams organisation. The app has no control over this; it is an admin/licensing concern.
- **JWT signature verification** — `JWTParser` decodes the ID token payload for display-only claims (name, email). It does **not** verify the signature. Token authenticity is guaranteed by MSAL's TLS-pinned token exchange, not by local JWT validation.

---

## Git History

| Commit | Description |
|---|---|
| Initial | Scaffold: SwiftUI app, AppConfig, AppLogger |
| +Auth | ASWebAuthenticationSession + PKCE auth flow |
| +Token | KeychainService, TokenManager, AuthToken, JWTParser |
| +Launch | AppLauncher with Teams/Outlook deep links |
| +Views | LoginView, DashboardView, ContentView |
| +MSAL | Migrate to MSAL with Microsoft Authenticator broker support |
| Fix scopes | Remove reserved OIDC scopes from acquireToken |
| Fix logging | Surface sub-error code for better diagnostics |
| Fix keychain | Use `com.microsoft.adalcache` group for broker key |
