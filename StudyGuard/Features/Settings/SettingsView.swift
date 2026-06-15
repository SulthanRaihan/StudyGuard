//
//  SettingsView.swift
//  StudyGuard
//

import SwiftUI

/// Alert sensitivity, voice, and account settings. Persists to UserDefaults via
/// `@AppStorage` (the session flow reads the same keys through `AppSettingsStore`).
struct SettingsView: View {
    @ObservedObject var auth: AuthService

    @AppStorage(AppSettingsStore.sensitivityKey) private var sensitivity = AlertSensitivity.medium.rawValue
    @AppStorage(AppSettingsStore.voiceLanguageKey) private var voiceLanguage = "id-ID"
    @AppStorage(AppSettingsStore.voiceEnabledKey) private var voiceEnabled = true
    @AppStorage(AppSettingsStore.postureAlertKey) private var postureAlert = true
    @AppStorage(AppSettingsStore.focusAlertKey) private var focusAlert = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    profileCard

                    section("Sensitivitas Alarm Postur") {
                        Picker("Sensitivitas", selection: $sensitivity) {
                            Text("Rendah (20 dtk)").tag(AlertSensitivity.low.rawValue)
                            Text("Sedang (10 dtk)").tag(AlertSensitivity.medium.rawValue)
                            Text("Tinggi (5 dtk)").tag(AlertSensitivity.high.rawValue)
                        }
                        .pickerStyle(.segmented)
                    }

                    section("Suara & Alarm") {
                        Toggle("Suara pelatih", isOn: $voiceEnabled)
                        Divider()
                        Picker("Bahasa suara", selection: $voiceLanguage) {
                            Text("Indonesia").tag("id-ID")
                            Text("English").tag("en-US")
                        }
                        Divider()
                        Toggle("Alarm postur", isOn: $postureAlert)
                        Divider()
                        Toggle("Alarm fokus", isOn: $focusAlert)
                    }
                    .tint(Theme.orange)

                    Button("Keluar", role: .destructive) { auth.signOut() }
                        .buttonStyle(.sgSecondary)

                    Text("StudyGuard v1.0")
                        .font(.caption2).foregroundStyle(Theme.muted)

                    Color.clear.frame(height: 90)
                }
                .padding(20)
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            BrandImage(name: "GuriHi", fallbackSystemName: "person.crop.circle.fill")
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(auth.displayName ?? "Pelajar")
                    .font(.title3.bold()).foregroundStyle(Theme.navy)
                Text("Pengaturan").font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sgCard()
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundStyle(Theme.navy)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sgCard()
    }
}
