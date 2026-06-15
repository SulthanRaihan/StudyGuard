//
//  HomeView.swift
//  StudyGuard
//

import SwiftUI

/// Dashboard: greeting, streak/XP/level stats, and the start-session button.
struct HomeView: View {
    @ObservedObject var auth: AuthService
    let onStart: () -> Void

    @State private var profile: FirebaseService.Profile?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                statsRow

                levelCard

                startButton

                Spacer(minLength: 12)
            }
            .padding(24)
        }
        .task { await load() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(profile?.name ?? auth.displayName ?? "Pelajar")
                    .font(.largeTitle.bold())
            }
            Spacer()
            Button {
                auth.signOut()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.title3)
            }
            .tint(.secondary)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(icon: "flame.fill", color: .orange,
                     value: "\(profile?.currentStreak ?? 0)", label: "Hari beruntun")
            statCard(icon: "star.fill", color: .yellow,
                     value: "\(profile?.totalXP ?? 0)", label: "Total XP")
        }
    }

    private func statCard(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title.bold())
                .redacted(reason: isLoading ? .placeholder : [])
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var levelCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "graduationcap.fill")
                .font(.title)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Level belajar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text((profile?.level ?? .beginner).rawValue)
                    .font(.title3.bold())
            }
            Spacer()
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var startButton: some View {
        Button(action: onStart) {
            Label("Mulai Sesi Belajar", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
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

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(auth: AuthService(), onStart: {})
    }
}
