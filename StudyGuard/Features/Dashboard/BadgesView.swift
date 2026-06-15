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

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                BrandImage(name: "GuriCelebrate", fallbackSystemName: "rosette")
                    .frame(height: 120)

                Text("\(unlockedCount) dari \(badges.count) lencana terbuka")
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
        .navigationTitle("Lencana")
        .navigationBarTitleDisplayMode(.inline)
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
        let name: String
        let detail: String
        let icon: String
        let unlocked: Bool
    }

    private var unlockedCount: Int { badges.filter(\.unlocked).count }

    private var badges: [Badge] {
        let count = sessions.count
        let hour: (Date) -> Int = { Calendar.current.component(.hour, from: $0) }
        let mathCount = sessions.filter { $0.subject == "Matematika" }.count

        return [
            Badge(name: "Sesi Pertama", detail: "Selesaikan 1 sesi", icon: "star.fill",
                  unlocked: count >= 1),
            Badge(name: "Postur Sempurna", detail: "Skor postur ≥ 95", icon: "figure.stand",
                  unlocked: sessions.contains { $0.postureScore >= 95 }),
            Badge(name: "Fokus Mendalam", detail: "60 menit fokus tinggi", icon: "brain.head.profile",
                  unlocked: sessions.contains { $0.totalSeconds >= 3600 && $0.focusScore >= 80 }),
            Badge(name: "7 Hari Beruntun", detail: "Belajar 7 hari", icon: "flame.fill",
                  unlocked: currentStreak >= 7),
            Badge(name: "Si Pagi", detail: "Mulai sebelum jam 8", icon: "sunrise.fill",
                  unlocked: sessions.contains { hour($0.endTime) < 8 }),
            Badge(name: "Si Malam", detail: "Belajar setelah jam 10 malam", icon: "moon.stars.fill",
                  unlocked: sessions.contains { hour($0.endTime) >= 22 }),
            Badge(name: "Ahli Matematika", detail: "10 sesi Matematika", icon: "function",
                  unlocked: mathCount >= 10),
            Badge(name: "Maraton Belajar", detail: "Satu sesi ≥ 90 menit", icon: "timer",
                  unlocked: sessions.contains { $0.totalSeconds >= 5400 })
        ]
    }
}
