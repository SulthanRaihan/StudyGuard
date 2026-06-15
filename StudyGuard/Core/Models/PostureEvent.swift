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
}

enum PostureSeverity: String, Codable {
    case mild, moderate, severe
}
