//
//  AgentModels.swift
//  StudyGuard
//
//  Codable structs mirroring the CrewAI backend's /analyze-session payload.
//  JSON uses snake_case; decode with `.convertFromSnakeCase`.
//

import Foundation

struct AgentSessionPayload: Encodable {
    let subject: String
    let durationMinutes: Int
    let postureScore: Double
    let focusScore: Double
    let dominantIssue: String?
    let postureAlertCount: Int
    let distractionCount: Int
    let focusTimeline: [Int]
    let breakMinutes: Int
}

struct AgentAnalysis: Decodable {
    struct Posture: Decodable {
        let score: Double
        let dominantIssue: String?
        let patterns: String
    }
    struct Focus: Decodable {
        let score: Double
        let deepFocusMinutes: Int
        let dropMinutes: [Int]
    }
    struct Exercise: Decodable, Identifiable {
        var id: String { name }
        let name: String
        let duration: Int
        let targetArea: String
        let instructions: String
    }

    let posture: Posture
    let focus: Focus
    let exercises: [Exercise]
    let narrative: String
}
