//
//  StudySession.swift
//  StudyGuard
//

import Foundation

struct StudySession: Codable, Identifiable {
    var id: String
    var userId: String
    var subject: String
    var startTime: Date
    var endTime: Date?
    var targetDuration: Int   // minutes, user's chosen duration
    var totalDuration: Int    // seconds, actual elapsed time
    var focusScore: Double    // 0.0 - 100.0
    var postureScore: Double  // 0.0 - 100.0
    var distractionCount: Int
    var postureAlertCount: Int
    var xpEarned: Int
    var groqSummary: String?
    var status: SessionStatus
}

enum SessionStatus: String, Codable {
    case completed
    case cancelled
}
