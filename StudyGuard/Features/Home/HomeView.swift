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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                buddyBanner
                statsRow
                levelCard
                startButton
                Color.clear.frame(height: 90) // clear the floating nav
            }
            .padding(20)
        }
        .background(Theme.cream.ignoresSafeArea())
        .task { await load() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BrandImage(name: "GuriHi", fallbackSystemName: "person.crop.circle.fill")
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting).font(.subheadline).foregroundStyle(Theme.muted)
                Text(profile?.name ?? auth.displayName ?? "Pelajar")
                    .font(.title.bold()).foregroundStyle(Theme.navy)
            }
            Spacer()
        }
    }

    private var buddyBanner: some View {
        HStack(spacing: 14) {
            BrandImage(name: "GuriCelebrate", fallbackSystemName: "sparkles")
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text("Teman belajarmu, Guri 🐱")
                    .font(.caption).foregroundStyle(Theme.muted)
                Text("Ayo jaga postur & fokus hari ini!")
                    .font(.headline).foregroundStyle(Theme.navy)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(icon: "flame.fill", color: Theme.orange,
                     value: "\(profile?.currentStreak ?? 0)", label: "Hari beruntun")
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

    private var levelCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "graduationcap.fill").font(.title).foregroundStyle(Theme.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Level belajar").font(.caption).foregroundStyle(Theme.muted)
                Text((profile?.level ?? .beginner).rawValue)
                    .font(.title3.bold()).foregroundStyle(Theme.navy)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sgCard()
    }

    private var startButton: some View {
        Button(action: onStart) {
            Label("Mulai Sesi Belajar", systemImage: "play.fill")
        }
        .buttonStyle(.sgPrimary)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 4..<11: return "Selamat pagi,"
        case 11..<15: return "Selamat siang,"
        case 15..<19: return "Selamat sore,"
        default: return "Selamat malam,"
        }
    }

    private func load() async {
        guard let uid = auth.currentUserId else { isLoading = false; return }
        profile = try? await FirebaseService.shared.fetchProfile(userId: uid)
        isLoading = false
    }
}
