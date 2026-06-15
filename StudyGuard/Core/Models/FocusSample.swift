//
//  FocusSample.swift
//  StudyGuard
//

import Foundation

/// A 30-second focus snapshot, used to build the focus timeline sent to Groq
/// at the end of a session.
struct FocusSample: Codable, Identifiable {
    var id: String
    var sessionId: String
    var userId: String
    var minuteMark: Int        // 0, 1, 2 ... N
    var focusScore: Double     // 0.0 - 100.0
    var state: FocusState      // "focused" | "drowsy" | "distracted"
    var timestamp: Date
}
