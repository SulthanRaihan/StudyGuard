//
//  HomeView.swift
//  StudyGuard
//

import SwiftUI

/// Dashboard: greeting, learning-buddy banner, streak/XP/level stats, start button.
struct HomeView: View {
    @ObservedObject var auth: AuthService
    let onStart: () -> Void

    @State private var profile: FirebaseService.Profile?
    @State private var isLoading = true
    @State private var showScan = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                guriGrowthCard
                statsRow
                startButton
                scanButton
                Color.clear.frame(height: 90) // clear the floating nav
            }
            .padding(20)
        }
        .background(Theme.cream.ignoresSafeArea())
        .task { await load() }
        .fullScreenCover(isPresented: $showScan) { ScanView() }
    }

    private var scanButton: some View {
        Button { showScan = true } label: {
            Label("Scan & Solve a Problem", systemImage: "text.viewfinder")
        }
        .buttonStyle(.sgSecondary)
    }

    private var header: some View {
        HStack(spacing: 12) {
            BrandImage(name: "GuriHi", fallbackSystemName: "person.crop.circle.fill")
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting).font(.subheadline).foregroundStyle(Theme.muted)
                Text(profile?.name ?? auth.displayName ?? "Learner")
                    .font(.title.bold()).foregroundStyle(Theme.navy)
            }
            Spacer()
        }
    }

    private var guriGrowthCard: some View {
        let xp = profile?.totalXP ?? 0
        let level = profile?.level ?? .beginner
        return VStack(spacing: 12) {
            HStack(spacing: 14) {
                BrandImage(name: guriImage(for: level), fallbackSystemName: "graduationcap.fill")
                    .frame(width: 60, height: 60)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Guri · \(level.rawValue)").font(.headline).foregroundStyle(Theme.navy)
                    Text(growthMessage(for: xp)).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
            }
            ProgressView(value: levelProgress(xp))
                .tint(Theme.orange)
            Text(nextLevelText(xp)).font(.caption2).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sgCard()
    }

    private func guriImage(for level: StudyLevel) -> String {
        switch level {
        case .beginner: return "GuriHi"
        case .scholar: return "GuriBreak"
        case .eliteScholar: return "GuriCelebrate"
        }
    }

    private func growthMessage(for xp: Int) -> String {
        switch xp {
        case 0: return "Start a session to help Guri grow! 🐱"
        case ..<500: return "Guri is getting stronger — keep going!"
        case ..<2000: return "Guri is proud of your progress! 🎓"
        default: return "Elite scholar — Guri is thriving! 🌟"
        }
    }

    /// Progress (0–1) through the current XP tier.
    private func levelProgress(_ xp: Int) -> Double {
        switch xp {
        case ..<500: return Double(xp) / 500
        case ..<2000: return Double(xp - 500) / 1500
        default: return 1
        }
    }

    private func nextLevelText(_ xp: Int) -> String {
        switch xp {
        case ..<500: return "\(500 - xp) XP to Scholar"
        case ..<2000: return "\(2000 - xp) XP to Elite Scholar"
        default: return "Max level reached"
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(icon: "flame.fill", color: Theme.orange,
                     value: "\(profile?.currentStreak ?? 0)", label: "Day streak")
            statCard(icon: "star.fill", color: .yellow,
                     value: "\(profile?.totalXP ?? 0)", label: "Total XP")
        }
    }

    private func statCard(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(value).font(.title.bold()).foregroundStyle(Theme.navy)
                .redacted(reason: isLoading ? .placeholder : [])
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sgCard()
    }

    private var startButton: some View {
        Button(action: onStart) {
            Label("Start Study Session", systemImage: "play.fill")
        }
        .buttonStyle(.sgPrimary)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 4..<11: return "Good morning,"
        case 11..<15: return "Good afternoon,"
        case 15..<19: return "Good evening,"
        default: return "Good night,"
        }
    }

    private func load() async {
        guard let uid = auth.currentUserId else { isLoading = false; return }
        profile = try? await FirebaseService.shared.fetchProfile(userId: uid)
        isLoading = false
    }
}
