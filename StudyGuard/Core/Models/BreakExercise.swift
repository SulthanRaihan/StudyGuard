//
//  BreakExercise.swift
//  StudyGuard
//

import Foundation

struct BreakExercise: Codable, Identifiable {
    var id: String
    var name: String
    var duration: Int          // seconds
    var targetArea: TargetArea
    var instructions: String?
    var gifUrl: String? = nil   // animated demo from ExerciseDB
    var completed: Bool = false
}

enum TargetArea: String, Codable {
    case neck
    case back
    case eyes
    case fullBody = "full_body"
}
