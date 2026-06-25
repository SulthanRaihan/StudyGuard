//
//  PostureEvent.swift
//  StudyGuard
//

import Foundation

struct PostureEvent: Codable, Identifiable {
    var id: String
    var sessionId: String
    var userId: String
    var timestamp: Date
    var type: PostureType
    var severity: PostureSeverity
    var duration: Int  // seconds
}

/// CoreML PostureClassifier output labels.
enum PostureType: String, Codable {
    case tup = "TUP"  // good posture (tegak)
    case tlf = "TLF"  // slouching forward (bungkuk depan)
    case tlb = "TLB"  // leaning back (bersandar belakang)
    case tlr = "TLR"  // tilted right (miring kanan)
    case tll = "TLL"  // tilted left (miring kiri)

    var isGood: Bool { self == .tup }

    /// Short coaching message for this posture problem. Shared by the voice
    /// coach (SessionManager) and the on-screen alert banner (SessionView) so
    /// both fire in sync with identical wording.
    var coachingMessage: String {
        switch self {
        case .tlf: return "You're slouching forward — sit up straight."
        case .tlb: return "You're leaning too far back."
        case .tlr: return "You're tilting to the right — straighten up."
        case .tll: return "You're tilting to the left — straighten up."
        case .tup: return ""
        }
    }
}

enum PostureSeverity: String, Codable {
    case mild, moderate, severe
}
