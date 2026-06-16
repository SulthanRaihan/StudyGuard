//
//  BadgesView.swift
//  StudyGuard
//

import SwiftUI

/// Achievement grid. Unlock state is derived from the user's session history
/// and current streak (see CLAUDE.md gamification rules).
struct BadgesView: View {
    let sessions: [FirebaseService.SessionRecord]
    let currentStreak: Int
    var userId: String? = nil

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                BrandImage(name: "GuriCelebrate", fallbackSystemName: "rosette")
                    .frame(height: 120)

                Text("\(unlockedCount) of \(badges.count) badges unlocked")
                    .font(.headline).foregroundStyle(Theme.navy)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(badges) { badge in
                        card(badge)
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.cream.ignoresSafeArea())
        .navigationTitle("Badges")
        .navigationBarTitleDisplayMode(.inline)
        .task { await persistUnlocked() }
    }

    private func persistUnlocked() async {
        guard let userId else { return }
        let unlocked = badges.filter(\.unlocked).map { (key: $0.key, name: $0.name, type: $0.type) }
        await FirebaseService.shared.syncAchievements(userId: userId, unlocked: unlocked)
    }

    private func card(_ badge: Badge) -> some View {
        VStack(spacing: 10) {
            Image(systemName: badge.icon)
                .font(.system(size: 34))
                .foregroundStyle(badge.unlocked ? Theme.orange : Theme.muted.opacity(0.5))
            Text(badge.name)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.navy)
                .multilineTextAlignment(.center)
            Text(badge.detail)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .sgCard(padding: 14)
        .opacity(badge.unlocked ? 1 : 0.55)
        .overlay(alignment: .topTrailing) {
            if !badge.unlocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(10)
            }
        }
    }

    // MARK: - Badge model

    private struct Badge: Identifiable {
        let id = UUID()
        let key: String
        let type: String
        let name: String
        let detail: String
        let icon: String
        let unlocked: Bool
    }

    private var unlockedCount: Int { badges.filter(\.unlocked).count }

    private var badges: [Badge] {
        let count = sessions.count
        let hour: (Date) -> Int = { Calendar.current.component(.hour, from: $0) }
        let mathCount = sessions.filter { $0.subject == "Mathematics" }.count

        return [
            Badge(key: "first_session", type: "milestone", name: "First Session",
                  detail: "Complete 1 session", icon: "star.fill",
                  unlocked: count >= 1),
            Badge(key: "posture_perfect", type: "posture", name: "Posture Perfect",
                  detail: "Posture score ≥ 95", icon: "figure.stand",
                  unlocked: sessions.contains { $0.postureScore >= 95 }),
            Badge(key: "deep_focus", type: "focus", name: "Deep Focus",
                  detail: "60 min of high focus", icon: "brain.head.profile",
                  unlocked: sessions.contains { $0.totalSeconds >= 3600 && $0.focusScore >= 80 }),
            Badge(key: "streak_7", type: "streak", name: "7-Day Streak",
                  detail: "Study 7 days in a row", icon: "flame.fill",
                  unlocked: currentStreak >= 7),
            Badge(key: "early_bird", type: "milestone", name: "Early Bird",
                  detail: "Start before 8 AM", icon: "sunrise.fill",
                  unlocked: sessions.contains { hour($0.endTime) < 8 }),
            Badge(key: "night_owl", type: "milestone", name: "Night Owl",
                  detail: "Study after 10 PM", icon: "moon.stars.fill",
                  unlocked: sessions.contains { hour($0.endTime) >= 22 }),
            Badge(key: "math_wizard", type: "milestone", name: "Math Wizard",
                  detail: "10 Mathematics sessions", icon: "function",
                  unlocked: mathCount >= 10),
            Badge(key: "study_marathon", type: "milestone", name: "Study Marathon",
                  detail: "One session ≥ 90 min", icon: "timer",
                  unlocked: sessions.contains { $0.totalSeconds >= 5400 })
        ]
    }
}
