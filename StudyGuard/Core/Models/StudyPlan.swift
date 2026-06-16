//
//  StudyPlan.swift
//  StudyGuard
//

import Foundation

/// One activity within a study-plan day.
struct StudyPlanTask: Identifiable, Codable {
    var id = UUID()
    let subject: String
    let activity: String
    let minutes: Int

    private enum CodingKeys: String, CodingKey { case subject, activity, minutes }
}

/// One day of the AI-generated study plan.
struct StudyPlanDay: Identifiable, Codable {
    var id = UUID()
    let day: String
    let tasks: [StudyPlanTask]

    private enum CodingKeys: String, CodingKey { case day, tasks }
}
