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
    @AppStorage(AppSettingsStore.voiceLanguageKey) private var voiceLanguage = "en-US"
    @AppStorage(AppSettingsStore.voiceEnabledKey) private var voiceEnabled = true
    @AppStorage(AppSettingsStore.postureAlertKey) private var postureAlert = true
    @AppStorage(AppSettingsStore.focusAlertKey) private var focusAlert = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    profileCard

                    section("Posture Alert Sensitivity") {
                        Picker("Sensitivity", selection: $sensitivity) {
                            Text("Low (20s)").tag(AlertSensitivity.low.rawValue)
                            Text("Medium (10s)").tag(AlertSensitivity.medium.rawValue)
                            Text("High (5s)").tag(AlertSensitivity.high.rawValue)
                        }
                        .pickerStyle(.segmented)
                    }

                    section("Voice & Alerts") {
                        Toggle("Coach voice", isOn: $voiceEnabled)
                        Divider()
                        Picker("Voice language", selection: $voiceLanguage) {
                            Text("English").tag("en-US")
                            Text("Indonesian").tag("id-ID")
                        }
                        Divider()
                        Toggle("Posture alerts", isOn: $postureAlert)
                        Divider()
                        Toggle("Focus alerts", isOn: $focusAlert)
                    }
                    .tint(Theme.orange)

                    Button("Sign Out", role: .destructive) { auth.signOut() }
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
                Text(auth.displayName ?? "Learner")
                    .font(.title3.bold()).foregroundStyle(Theme.navy)
                Text("Settings").font(.caption).foregroundStyle(Theme.muted)
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
