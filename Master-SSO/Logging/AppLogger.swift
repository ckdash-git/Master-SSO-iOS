//
//  AppLogger.swift
//  Master-SSO
//
//  Centralised os.Logger instances, one per subsystem category.
//  Use these throughout the app instead of print() or NSLog().
//
//  Console.app filter:  subsystem = com.cachatto.Master-SSO
//

import Foundation
import os

enum AppLogger {

    private static let subsystem: String =
        Bundle.main.bundleIdentifier ?? "com.cachatto.Master-SSO"

    /// Authentication flow events (start, redirect, code exchange, errors).
    static let auth   = Logger(subsystem: subsystem, category: "Auth")

    /// Token storage and retrieval events (Keychain read/write/delete).
    static let token  = Logger(subsystem: subsystem, category: "Token")

    /// External-app launch attempts (Teams, Outlook, App Store fallback).
    static let launch = Logger(subsystem: subsystem, category: "AppLaunch")

    /// General / uncategorised events.
    static let general = Logger(subsystem: subsystem, category: "General")
}
