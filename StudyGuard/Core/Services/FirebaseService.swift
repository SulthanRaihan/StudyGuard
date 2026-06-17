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

    /// A past session, for the dashboard, history, and badges.
    struct SessionRecord: Identifiable {
        let id: String
        let subject: String
        let endTime: Date
        let focusScore: Double
        let postureScore: Double
        let totalSeconds: Int
        let distractionCount: Int
        let postureAlertCount: Int
        let focusTimeline: [Int]
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
            let timeline = (data["focusTimeline"] as? [NSNumber])?.map(\.intValue)
                ?? (data["focusTimeline"] as? [Int]) ?? []
            return SessionRecord(
                id: doc.documentID,
                subject: data["subject"] as? String ?? "",
                endTime: end,
                focusScore: data["focusScore"] as? Double ?? 0,
                postureScore: data["postureScore"] as? Double ?? 0,
                totalSeconds: data["totalDuration"] as? Int ?? 0,
                distractionCount: data["distractionCount"] as? Int ?? 0,
                postureAlertCount: data["postureAlertCount"] as? Int ?? 0,
                focusTimeline: timeline
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

    // MARK: - Settings sync

    /// Persists the user's settings map (merged into the user document).
    func saveSettings(userId: String, settings: [String: Any]) async throws {
        try await db.collection("users").document(userId).setData(["settings": settings], merge: true)
    }

    /// Reads the user's settings map, if any.
    func fetchSettings(userId: String) async throws -> [String: Any]? {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        return snapshot.data()?["settings"] as? [String: Any]
    }

    // MARK: - Study plan

    func saveStudyPlan(userId: String, days: [StudyPlanDay]) async {
        guard let data = try? JSONEncoder().encode(days),
              let json = String(data: data, encoding: .utf8) else { return }
        try? await db.collection("users").document(userId).setData(["studyPlan": json], merge: true)
    }

    func fetchStudyPlan(userId: String) async -> [StudyPlanDay] {
        guard let snapshot = try? await db.collection("users").document(userId).getDocument(),
              let json = snapshot.data()?["studyPlan"] as? String,
              let data = json.data(using: .utf8),
              let days = try? JSONDecoder().decode([StudyPlanDay].self, from: data) else { return [] }
        return days
    }

    // MARK: - Achievements

    /// Records any newly-unlocked badges in the user document (keyed map), stamping
    /// `unlockedAt` once. Existing entries are left untouched.
    func syncAchievements(userId: String, unlocked: [(key: String, name: String, type: String)]) async {
        let ref = db.collection("users").document(userId)
        let snapshot = try? await ref.getDocument()
        var map = (snapshot?.data()?["achievements"] as? [String: Any]) ?? [:]
        var changed = false
        for badge in unlocked where map[badge.key] == nil {
            map[badge.key] = [
                "name": badge.name,
                "type": badge.type,
                "unlockedAt": Timestamp(date: Date())
            ]
            changed = true
        }
        if changed {
            try? await ref.setData(["achievements": map], merge: true)
        }
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
                       distractionCount: Int = 0,
                       focusTimeline: [Int] = [],
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
            "distractionCount": distractionCount,
            "postureAlertCount": postureAlertCount,
            "focusTimeline": focusTimeline,
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

/// Derived insights over a set of past sessions (for the planner & weekly report).
enum SessionStats {
    /// Hour of day (0–23) with the highest average focus.
    static func bestFocusHour(_ sessions: [FirebaseService.SessionRecord]) -> Int? {
        guard !sessions.isEmpty else { return nil }
        let calendar = Calendar.current
        let byHour = Dictionary(grouping: sessions) { calendar.component(.hour, from: $0.endTime) }
        let avg = byHour.mapValues { $0.map(\.focusScore).reduce(0, +) / Double($0.count) }
        return avg.max { $0.value < $1.value }?.key
    }

    /// Subject with the lowest average focus.
    static func weakestSubject(_ sessions: [FirebaseService.SessionRecord]) -> String? {
        let named = sessions.filter { !$0.subject.isEmpty }
        guard !named.isEmpty else { return nil }
        let bySubject = Dictionary(grouping: named, by: \.subject)
        let avg = bySubject.mapValues { $0.map(\.focusScore).reduce(0, +) / Double($0.count) }
        return avg.min { $0.value < $1.value }?.key
    }
}
