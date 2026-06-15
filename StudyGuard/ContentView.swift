//
//  ContentView.swift
//  StudyGuard
//

import SwiftUI

/// Root router: gates on auth state, then runs the Home -> PreSession -> Session flow.
struct ContentView: View {
    @StateObject private var auth = AuthService()

    var body: some View {
        if auth.isAuthenticated {
            HomeFlow(auth: auth)
        } else {
            AuthFlow(auth: auth)
        }
    }
}

/// Switches between login and registration.
private struct AuthFlow: View {
    @ObservedObject var auth: AuthService
    @State private var showRegister = false

    var body: some View {
        if showRegister {
            RegisterView(auth: auth) { showRegister = false }
        } else {
            LoginView(auth: auth) { showRegister = true }
        }
    }
}

/// Home -> PreSession setup -> live Session, persisting the result on finish.
private struct HomeFlow: View {
    @ObservedObject var auth: AuthService
    @State private var activeSession: SessionManager?
    @State private var showSetup = false

    var body: some View {
        if let session = activeSession {
            SessionView(session: session) { finish(session) }
                .id(ObjectIdentifier(session))
        } else if showSetup {
            PreSessionSetupView { subject, duration in
                activeSession = SessionManager(subject: subject, targetDuration: duration)
                showSetup = false
            }
        } else {
            HomeView(auth: auth) { showSetup = true }
        }
    }

    /// Persist the completed session, then return Home.
    private func finish(_ session: SessionManager) {
        let userId = auth.currentUserId
        let subject = session.subject
        let totalSeconds = session.elapsedSeconds
        let targetMinutes = session.targetDuration
        let posture = session.avgPosture
        let focus = session.avgFocus
        let alerts = session.postureAlertCount
        let startedAt = session.startedAt

        activeSession = nil

        guard let userId, totalSeconds > 0 else { return }
        Task {
            try? await FirebaseService.shared.recordSession(
                userId: userId,
                subject: subject,
                startTime: startedAt,
                totalSeconds: totalSeconds,
                targetMinutes: targetMinutes,
                postureScore: posture,
                focusScore: focus,
                postureAlertCount: alerts,
                status: "completed"
            )
        }
    }
}
