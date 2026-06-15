//
//  FirebaseService.swift
//  StudyGuard
//

import Foundation
import FirebaseFirestore

/// All Firestore reads/writes. Uses plain dictionaries (version-stable across
/// SDK releases) rather than Codable mapping.
final class FirebaseService {

    static let shared = FirebaseService()
    private let db = Firestore.firestore()
    private init() {}

    /// Dashboard view of a user's profile.
    struct Profile {
        let name: String
        let totalXP: Int
        let currentStreak: Int
        let longestStreak: Int
        var level: StudyLevel { StudyLevel.level(forXP: totalXP) }
    }

    /// A past session, for the dashboard and badges.
    struct SessionRecord: Identifiable {
        let id: String
        let subject: String
        let endTime: Date
        let focusScore: Double
        let postureScore: Double
        let totalSeconds: Int
    }

    /// Recent sessions, newest first. Filters by `userId` only (no composite index
    /// needed) and sorts client-side.
    func fetchRecentSessions(userId: String, limit: Int = 50) async throws -> [SessionRecord] {
        let snapshot = try await db.collection("sessions")
            .whereField("userId", isEqualTo: userId)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> SessionRecord? in
            let data = doc.data()
            guard let end = (data["endTime"] as? Timestamp)?.dateValue() else { return nil }
            return SessionRecord(
                id: doc.documentID,
                subject: data["subject"] as? String ?? "",
                endTime: end,
                focusScore: data["focusScore"] as? Double ?? 0,
                postureScore: data["postureScore"] as? Double ?? 0,
                totalSeconds: data["totalDuration"] as? Int ?? 0
            )
        }
        .sorted { $0.endTime > $1.endTime }
    }

    // MARK: - User profile

    func createUserProfile(userId: String, name: String, email: String) async throws {
        let data: [String: Any] = [
            "name": name,
            "email": email,
            "createdAt": Timestamp(date: Date()),
            "studyLevel": StudyLevel.beginner.rawValue,
            "totalXP": 0,
            "currentStreak": 0,
            "longestStreak": 0
        ]
        try await db.collection("users").document(userId).setData(data)
    }

    func fetchProfile(userId: String) async throws -> Profile {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        let data = snapshot.data() ?? [:]
        return Profile(
            name: data["name"] as? String ?? "Pelajar",
            totalXP: data["totalXP"] as? Int ?? 0,
            currentStreak: data["currentStreak"] as? Int ?? 0,
            longestStreak: data["longestStreak"] as? Int ?? 0
        )
    }

    // MARK: - Session persistence

    /// Saves a finished session and updates the user's XP/streak.
    /// Returns the XP earned for this session.
    @discardableResult
    func recordSession(userId: String,
                       subject: String,
                       startTime: Date,
                       totalSeconds: Int,
                       targetMinutes: Int,
                       postureScore: Double,
                       focusScore: Double,
                       postureAlertCount: Int,
                       status: String) async throws -> Int {

        let userRef = db.collection("users").document(userId)
        let snapshot = try await userRef.getDocument()
        let data = snapshot.data() ?? [:]

        var totalXP = data["totalXP"] as? Int ?? 0
        var currentStreak = data["currentStreak"] as? Int ?? 0
        var longestStreak = data["longestStreak"] as? Int ?? 0
        let lastStudy = (data["lastStudyDate"] as? Timestamp)?.dateValue()

        // Streak: +1 if last study was yesterday, reset to 1 after a gap, unchanged today.
        let calendar = Calendar.current
        if let last = lastStudy {
            if calendar.isDateInToday(last) {
                // already counted today
            } else if calendar.isDateInYesterday(last) {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }
        longestStreak = max(longestStreak, currentStreak)

        // XP (see CLAUDE.md gamification rules).
        let focusMinutes = Double(totalSeconds) / 60.0 * (focusScore / 100.0)
        let baseXP = Int(focusMinutes * 10)
        let postureBonus = postureScore > 80 ? 50 : 0
        let focusBonus = focusScore > 80 ? 50 : 0
        let streakBonus = currentStreak * 10
        let xpEarned = baseXP + postureBonus + focusBonus + streakBonus
        totalXP += xpEarned

        // Write the session document.
        let sessionData: [String: Any] = [
            "userId": userId,
            "subject": subject,
            "startTime": Timestamp(date: startTime),
            "endTime": Timestamp(date: Date()),
            "targetDuration": targetMinutes,
            "totalDuration": totalSeconds,
            "focusScore": focusScore,
            "postureScore": postureScore,
            "distractionCount": 0,
            "postureAlertCount": postureAlertCount,
            "xpEarned": xpEarned,
            "status": status
        ]
        try await db.collection("sessions").document(UUID().uuidString).setData(sessionData)

        // Update the user's aggregates.
        try await userRef.updateData([
            "totalXP": totalXP,
            "currentStreak": currentStreak,
            "longestStreak": longestStreak,
            "studyLevel": StudyLevel.level(forXP: totalXP).rawValue,
            "lastStudyDate": Timestamp(date: Date())
        ])

        return xpEarned
    }
}
