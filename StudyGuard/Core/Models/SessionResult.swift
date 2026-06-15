//
//  SessionResult.swift
//  StudyGuard
//

import Foundation

/// A finished session's data, used to drive the summary, break, and persistence.
struct SessionResult {
    let subject: String
    let totalSeconds: Int
    let targetMinutes: Int
    let avgPosture: Double
    let avgFocus: Double
    let postureAlertCount: Int
    let dominantIssue: PostureType?
    let focusTimeline: [Int]     // per-minute focus score
    let startedAt: Date

    var durationMinutes: Int { totalSeconds / 60 }

    /// Recommended break length for the chosen duration (Pomodoro mapping).
    var breakMinutes: Int {
        switch targetMinutes {
        case ..<50: return 5
        case 50..<75: return 10
        default: return 15
        }
    }

    /// Compact per-minute focus string for the Groq prompt, e.g. "menit 1-5: 90,88,...".
    var focusTimelineString: String {
        guard !focusTimeline.isEmpty else { return "tidak ada data" }
        return focusTimeline.enumerated()
            .map { "menit \($0.offset + 1): \($0.element)" }
            .joined(separator: ", ")
    }
}
