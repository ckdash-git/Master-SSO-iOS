//
//  AppLauncher.swift
//  Master-SSO
//
//  Handles deep-link launching of Microsoft apps installed on the device.
//  Performs an App Store fallback when the target app is not installed.
//
//  SSO note: these launches do not inject credentials. If the user authenticated
//  via ASWebAuthenticationSession with prefersEphemeralWebBrowserSession=false,
//  the shared browser cookie may enable transparent SSO inside Teams / Outlook
//  when they open their own embedded browser sessions.
//

import UIKit

@MainActor
final class AppLauncher {

    static let shared = AppLauncher()
    private init() {}

    private let logger = AppLogger.launch

    // MARK: - Microsoft Teams

    /// Opens Microsoft Teams, or navigates to the App Store listing if not installed.
    func openTeams() {
        logger.info("Requesting launch of Microsoft Teams")
        launch(
            appSchemeURL:   "msteams://",
            appStoreLinkURL: "https://apps.apple.com/app/microsoft-teams/id1113153706",
            appName:        "Microsoft Teams"
        )
    }

    // MARK: - Microsoft Outlook

    /// Opens Microsoft Outlook, or navigates to the App Store listing if not installed.
    func openOutlook() {
        logger.info("Requesting launch of Microsoft Outlook")
        launch(
            appSchemeURL:    "ms-outlook://",
            appStoreLinkURL: "https://apps.apple.com/app/microsoft-outlook/id951937596",
            appName:         "Microsoft Outlook"
        )
    }

    // MARK: - Internal launcher

    private func launch(
        appSchemeURL:    String,
        appStoreLinkURL: String,
        appName:         String
    ) {
        guard let schemeURL  = URL(string: appSchemeURL),
              let storeURL   = URL(string: appStoreLinkURL) else {
            logger.error("Invalid URL strings for \(appName)")
            return
        }

        if UIApplication.shared.canOpenURL(schemeURL) {
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
