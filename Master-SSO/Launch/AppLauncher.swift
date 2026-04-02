//
//  AppLauncher.swift
//  Master-SSO
//
//  Handles deep-link launching of Microsoft and Google apps installed on the device.
//  Falls back to the App Store when the target app is not installed.
//
//  Microsoft SSO behaviour:
//  loginHint + tenantId are passed in the URL scheme so Teams/Outlook know which
//  account and tenant to authenticate against. With the MSAL broker active, apps
//  receive tokens silently from the shared com.microsoft.adalcache keychain group.
//
//  Google SSO behaviour:
//  Google apps share authentication through Google's own account system on iOS.
//  If the user is already signed into the same Google account in Gmail or any other
//  Google app, further Google apps open without re-authentication.
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
    func openTeams(loginHint: String? = nil, tenantId: String? = nil) {
        logger.info("Requesting launch of Microsoft Teams (hint: \(loginHint ?? "none"))")

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
    func openOutlook(loginHint: String? = nil) {
        logger.info("Requesting launch of Microsoft Outlook (hint: \(loginHint ?? "none"))")

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

    // MARK: - Gmail

    /// Opens Gmail. Passes authuser hint when available so Gmail selects the right account.
    func openGmail(loginHint: String? = nil) {
        logger.info("Requesting launch of Gmail (hint: \(loginHint ?? "none"))")
        var urlString = "googlegmail://"
        if let hint = loginHint {
            urlString += "?authuser=\(hint.urlEncoded)"
        }
        launch(
            appSchemeURL:    urlString,
            appStoreLinkURL: "https://apps.apple.com/app/gmail-email-by-google/id422689480",
            appName:         "Gmail"
        )
    }

    // MARK: - Google Meet

    /// Opens Google Meet.
    func openGoogleMeet() {
        logger.info("Requesting launch of Google Meet")
        launch(
            appSchemeURL:    "meet://",
            appStoreLinkURL: "https://apps.apple.com/app/google-meet/id1096918571",
            appName:         "Google Meet"
        )
    }

    // MARK: - Google Drive

    /// Opens Google Drive.
    func openGoogleDrive() {
        logger.info("Requesting launch of Google Drive")
        launch(
            appSchemeURL:    "googledrive://",
            appStoreLinkURL: "https://apps.apple.com/app/google-drive/id507874739",
            appName:         "Google Drive"
        )
    }

    // MARK: - Google Calendar

    /// Opens Google Calendar.
    func openGoogleCalendar() {
        logger.info("Requesting launch of Google Calendar")
        launch(
            appSchemeURL:    "googlecalendar://",
            appStoreLinkURL: "https://apps.apple.com/app/google-calendar-time-planner/id909319292",
            appName:         "Google Calendar"
        )
    }

    // MARK: - Diagnostics

    /// Logs the install status of every managed app at startup.
    func logInstallStatus() {
        let apps: [(name: String, scheme: String)] = [
            ("Microsoft Teams",   "msteams://"),
            ("Microsoft Outlook", "ms-outlook://"),
            ("Gmail",             "googlegmail://"),
            ("Google Meet",       "meet://"),
            ("Google Drive",      "googledrive://"),
            ("Google Calendar",   "googlecalendar://"),
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

