//
//  FocusEvent.swift
//  StudyGuard
//

import Foundation

struct FocusEvent: Codable, Identifiable {
    var id: String
    var sessionId: String
    var userId: String
    var timestamp: Date
    var type: FocusState
    var duration: Int  // seconds
}

enum FocusState: String, Codable {
    case focused
    case drowsy
    case distracted
}
