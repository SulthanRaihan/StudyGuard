//
//  MainView.swift
//  StudyGuard
//

import SwiftUI

/// Authenticated root: a floating pill tab bar (Home / Stats / Settings) plus the
/// full-screen study flow (PreSession -> Session -> Summary -> Break).
struct MainView: View {
    @ObservedObject var auth: AuthService

    @State private var tab: Tab = .home
    @State private var activeSession: SessionManager?
    @State private var summaryResult: SessionResult?
    @State private var showSetup = false

    enum Tab: Int { case home, plan, stats, settings }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.cream.ignoresSafeArea()
            content
            if showTabBar {
                pillNav
            }
        }
        .task { await loadCloudSettings() }
    }

    /// Pull the user's saved settings from Firestore into local defaults on launch.
    private func loadCloudSettings() async {
        guard let uid = auth.currentUserId,
              let settings = try? await FirebaseService.shared.fetchSettings(userId: uid) else { return }
        let defaults = UserDefaults.standard
        if let v = settings["alertSensitivity"] as? String { defaults.set(v, forKey: AppSettingsStore.sensitivityKey) }
        if let v = settings["voiceLanguage"] as? String { defaults.set(v, forKey: AppSettingsStore.voiceLanguageKey) }
        if let v = settings["voiceEnabled"] as? Bool { defaults.set(v, forKey: AppSettingsStore.voiceEnabledKey) }
        if let v = settings["postureAlertEnabled"] as? Bool { defaults.set(v, forKey: AppSettingsStore.postureAlertKey) }
        if let v = settings["focusAlertEnabled"] as? Bool { defaults.set(v, forKey: AppSettingsStore.focusAlertKey) }
    }

    @ViewBuilder
    private var content: some View {
        if let session = activeSession {
            SessionView(session: session) { result in
                activeSession = nil
                save(result)
                summaryResult = result
            }
            .id(ObjectIdentifier(session))
        } else if let result = summaryResult {
            SessionSummaryView(result: result) { summaryResult = nil }
        } else if showSetup {
            PreSessionSetupView { subject, duration in
                activeSession = makeSession(subject: subject, duration: duration)
                showSetup = false
            }
        } else {
            switch tab {
            case .home: HomeView(auth: auth) { showSetup = true }
            case .plan: PlannerView(auth: auth)
            case .stats: DashboardView(auth: auth)
            case .settings: SettingsView(auth: auth)
            }
        }
    }

    private var showTabBar: Bool {
        activeSession == nil && summaryResult == nil && !showSetup
    }

    // MARK: - Floating pill nav

    private var pillNav: some View {
        HStack(spacing: 8) {
            navItem(.home, "house.fill", "Home")
            navItem(.plan, "calendar", "Plan")
            navItem(.stats, "chart.bar.fill", "Stats")
            navItem(.settings, "gearshape.fill", "Settings")
        }
        .padding(6)
        .background(Theme.navy, in: Capsule())
        .shadow(color: Theme.navy.opacity(0.3), radius: 12, y: 6)
        .padding(.bottom, 8)
    }

    private func navItem(_ item: Tab, _ icon: String, _ label: String) -> some View {
        let selected = tab == item
        return Button {
            tab = item
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                if selected { Text(label).font(.subheadline.weight(.semibold)) }
            }
            .foregroundStyle(selected ? .white : .white.opacity(0.6))
            .padding(.vertical, 12)
            .padding(.horizontal, selected ? 18 : 16)
            .background(selected ? AnyShapeStyle(Theme.orange) : AnyShapeStyle(.clear), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Session creation + persistence

    private func makeSession(subject: String, duration: Int) -> SessionManager {
        SessionManager(subject: subject, targetDuration: duration,
                       sensitivity: AppSettingsStore.sensitivity,
                       voiceLanguage: AppSettingsStore.voiceLanguage,
                       voiceEnabled: AppSettingsStore.voiceEnabled)
    }

    private func save(_ result: SessionResult) {
        guard let userId = auth.currentUserId, result.totalSeconds > 0 else { return }
        Task {
            try? await FirebaseService.shared.recordSession(
                userId: userId, subject: result.subject, startTime: result.startedAt,
                totalSeconds: result.totalSeconds, targetMinutes: result.targetMinutes,
                postureScore: result.avgPosture, focusScore: result.avgFocus,
                postureAlertCount: result.postureAlertCount,
                distractionCount: result.distractionCount,
                focusTimeline: result.focusTimeline, status: "completed"
            )
        }
    }
}
