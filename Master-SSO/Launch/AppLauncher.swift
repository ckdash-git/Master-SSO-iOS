//
//  AppLauncher.swift
//  Master-SSO
//
//  Handles deep-link launching of Microsoft apps installed on the device.
//  Performs an App Store fallback when the target app is not installed.
//
//  SSO behaviour:
//  - loginHint + tenantId are passed in the URL scheme so Teams/Outlook
//    know which account and tenant to authenticate against, avoiding a
//    blank sign-in screen.
//  - Credentials are never injected. The user still authenticates inside
//    the Microsoft app, but the shared Safari browser cookies from the
//    preceding ASWebAuthenticationSession may allow that to happen
//    silently if Teams/Outlook use non-ephemeral ASWebAuthenticationSession
//    internally (best-effort; depends on Microsoft's MSAL configuration).
//

import os
import UIKit

@MainActor
final class AppLauncher {

    static let shared = AppLauncher()
    private init() {}

    private let logger = AppLogger.launch

    // MARK: - Microsoft Teams

    /// Opens Microsoft Teams with an optional account hint.
    /// - Parameters:
    ///   - loginHint: User's email address — pre-selects the account in Teams.
    ///   - tenantId:  Azure AD tenant ID — directs Teams to the right tenant.
    func openTeams(loginHint: String? = nil, tenantId: String? = nil) {
        logger.info("Requesting launch of Microsoft Teams (hint: \(loginHint ?? "none"))")

        // Build URL with auth hints when available.
        // msteams://?tenantId=<tid>&loginhint=<email>
        var urlString = "msteams://"
        var params: [String: String] = [:]
        if let tenantId  { params["tenantId"]  = tenantId }
        if let loginHint { params["loginhint"] = loginHint }
        if !params.isEmpty {
            let query = params
                .map { "\($0.key)=\($0.value.urlEncoded)" }
                .joined(separator: "&")
            urlString += "?\(query)"
        }

        launch(
            appSchemeURL:    urlString,
            appStoreLinkURL: "https://apps.apple.com/app/microsoft-teams/id1113153706",
            appName:         "Microsoft Teams"
        )
    }

    // MARK: - Microsoft Outlook

    /// Opens Microsoft Outlook with an optional account hint.
    /// - Parameter loginHint: User's email address — pre-selects the account in Outlook.
    func openOutlook(loginHint: String? = nil) {
        logger.info("Requesting launch of Microsoft Outlook (hint: \(loginHint ?? "none"))")

        // ms-outlook:///?accountId=<email> is supported in recent Outlook builds.
        var urlString = "ms-outlook://"
        if let loginHint {
            urlString += "?accountId=\(loginHint.urlEncoded)"
        }

        launch(
            appSchemeURL:    urlString,
            appStoreLinkURL: "https://apps.apple.com/app/microsoft-outlook/id951937596",
            appName:         "Microsoft Outlook"
        )
    }

    // MARK: - Diagnostics

    /// Logs the install status of every managed Microsoft app.
    /// Call once at app startup to capture the environment in Console.app.
    func logInstallStatus() {
        let apps: [(name: String, scheme: String)] = [
            ("Microsoft Teams",   "msteams://"),
            ("Microsoft Outlook", "ms-outlook://"),
        ]
        for app in apps {
            if let url = URL(string: app.scheme) {
                let installed = UIApplication.shared.canOpenURL(url)
                logger.info("\(app.name) installed: \(installed)")
            }
        }
    }

    // MARK: - Internal launcher

    private func launch(
        appSchemeURL:    String,
        appStoreLinkURL: String,
        appName:         String
    ) {
        guard let schemeURL = URL(string: appSchemeURL),
              let storeURL  = URL(string: appStoreLinkURL) else {
            logger.error("Invalid URL strings for \(appName)")
            return
        }

        // canOpenURL requires the base scheme (without query params) to work.
        // Use a clean base URL for the availability check.
        let baseScheme = schemeURL.scheme.map { URL(string: "\($0)://") } ?? schemeURL

        if UIApplication.shared.canOpenURL(baseScheme ?? schemeURL) {
            logger.info("\(appName) is installed — opening via URL scheme")
            UIApplication.shared.open(schemeURL, options: [:]) { [weak self] success in
                if success {
                    self?.logger.info("\(appName) opened successfully")
                } else {
                    self?.logger.error("Failed to open \(appName) despite positive canOpenURL")
                }
            }
        } else {
            logger.warning("\(appName) not installed — redirecting to App Store")
            UIApplication.shared.open(storeURL, options: [:]) { [weak self] success in
                if success {
                    self?.logger.info("App Store opened for \(appName)")
                } else {
                    self?.logger.error("Failed to open App Store for \(appName)")
                }
            }
        }
    }
}

// MARK: - String helpers

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
