//
//  User.swift
//  StudyGuard
//

import Foundation

struct User: Codable, Identifiable {
    var id: String
    var name: String
    var email: String
    var createdAt: Date
    var studyLevel: StudyLevel
    var totalXP: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastStudyDate: Date?
    var settings: UserSettings
}

enum StudyLevel: String, Codable {
    case beginner = "Beginner"
    case scholar = "Scholar"
    case eliteScholar = "Elite Scholar"

    static func level(forXP xp: Int) -> StudyLevel {
        switch xp {
        case ..<500: return .beginner
        case 500..<2000: return .scholar
        default: return .eliteScholar
        }
    }
}

struct UserSettings: Codable {
    var pomodoroDuration: Int = 25
    var breakDuration: Int = 5
    var postureAlertEnabled: Bool = true
    var focusAlertEnabled: Bool = true
    var waterReminderInterval: Int = 30
    var voiceLanguage: String = "id-ID"
    var alertSensitivity: AlertSensitivity = .medium
}

enum AlertSensitivity: String, Codable {
    case low, medium, high

    /// Seconds of sustained bad posture before a voice alert fires.
    var thresholdSeconds: Int {
        switch self {
        case .low: return 20
        case .medium: return 10
        case .high: return 5
        }
    }
}
