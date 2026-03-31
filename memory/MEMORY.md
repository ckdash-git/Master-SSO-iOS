# Master-SSO iOS Project

## Project Overview
iOS app implementing federated Microsoft SSO via custom IdP, with Teams/Outlook launch.
- Bundle ID: `com.cachatto.Master-SSO`
- Deployment target: iOS 26.2
- Swift version: 5.0 (Xcode 26, Swift 6.2)
- Build settings: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- Dev team: 5897SV9S2K

## File Structure
```
Master-SSO/
├── Config/AppConfig.swift          — OAuth/OIDC endpoints + client credentials (placeholders)
├── Logging/AppLogger.swift         — os.Logger instances by category
├── Auth/
│   ├── PKCEHelper.swift            — RFC-7636 S256 PKCE generator (CryptoKit)
│   ├── AuthError.swift             — Typed error enum
│   └── AuthManager.swift           — @MainActor ObservableObject; ASWebAuthenticationSession
├── Models/
│   ├── AuthToken.swift             — Codable token model; Keychain-persisted
│   ├── TokenResponse.swift         — Decodable token endpoint response DTO
│   └── JWTParser.swift             — Base64URL payload decoder (no signature check)
├── Token/
│   ├── KeychainService.swift       — Security.framework Keychain wrapper
│   └── TokenManager.swift          — JSON-encode/decode AuthToken to Keychain
├── Launch/
│   └── AppLauncher.swift           — Teams (msteams://) + Outlook (ms-outlook://) launcher
├── Views/
│   ├── LoginView.swift             — Sign-in button + error banner
│   └── DashboardView.swift         — Identity card + app launch buttons + sign-out
├── ContentView.swift               — Root router (unauthenticated ↔ authenticated)
├── Master_SSOApp.swift             — @main App; injects AuthManager as @EnvironmentObject
└── Info.plist                      — CFBundleURLTypes, LSApplicationQueriesSchemes, etc.
```

## Key Architecture Decisions
- `prefersEphemeralWebBrowserSession = false` on ASWebAuthenticationSession → shares Safari cookies → best-effort SSO
- PKCE (S256) mandatory; no client secret
- Tokens stored as JSON in Keychain with `WhenUnlockedThisDeviceOnly`
- JWTParser is display-only; never used for security decisions
- All logging via `os.Logger` — no `print()` statements

## Configuration Required Before Running
Update `AppConfig.swift`:
- `clientId` — Azure AD App Registration client ID
- `tenantId` — Azure AD tenant ID (or "common")
- `redirectURI` — must match "master-sso://auth/callback" registered in Azure

## Info.plist Keys
- `CFBundleURLTypes` → scheme `master-sso` (redirect callback)
- `LSApplicationQueriesSchemes` → `msteams`, `ms-outlook`

## Git History
feature/idp-ms-sso-integration merged to main with 9 logical commits + Info.plist commit.
