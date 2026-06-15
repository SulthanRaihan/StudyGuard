//
//  AppSettings.swift
//  StudyGuard
//

import Foundation

/// Locally-persisted user preferences (UserDefaults). `SettingsView` binds to the
/// same keys via `@AppStorage`; the session flow reads them when starting a session.
enum AppSettingsStore {
    static let sensitivityKey = "alertSensitivity"
    static let voiceLanguageKey = "voiceLanguage"
    static let voiceEnabledKey = "voiceEnabled"
    static let postureAlertKey = "postureAlertEnabled"
    static let focusAlertKey = "focusAlertEnabled"

    static var sensitivity: AlertSensitivity {
        AlertSensitivity(rawValue: UserDefaults.standard.string(forKey: sensitivityKey) ?? "medium") ?? .medium
    }
    static var voiceLanguage: String {
        UserDefaults.standard.string(forKey: voiceLanguageKey) ?? "id-ID"
    }
    static var voiceEnabled: Bool {
        UserDefaults.standard.object(forKey: voiceEnabledKey) as? Bool ?? true
    }
}
