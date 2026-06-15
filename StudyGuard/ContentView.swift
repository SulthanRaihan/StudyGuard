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

/// Home -> PreSession -> Session -> Summary -> Break, persisting the result on finish.
private struct HomeFlow: View {
    @ObservedObject var auth: AuthService
    @State private var activeSession: SessionManager?
    @State private var summaryResult: SessionResult?
    @State private var breakResult: SessionResult?
    @State private var showSetup = false

    var body: some View {
        if let session = activeSession {
            SessionView(session: session) { result in
                activeSession = nil
                save(result)
                summaryResult = result
            }
            .id(ObjectIdentifier(session))
        } else if let result = summaryResult {
            SessionSummaryView(result: result,
                               onStartBreak: { summaryResult = nil; breakResult = result },
                               onDone: { summaryResult = nil })
        } else if let result = breakResult {
            BreakView(result: result) { breakResult = nil }
        } else if showSetup {
            PreSessionSetupView { subject, duration in
                activeSession = SessionManager(subject: subject, targetDuration: duration)
                showSetup = false
            }
        } else {
            HomeView(auth: auth) { showSetup = true }
        }
    }

    /// Persist the completed session and update the user's XP/streak.
    private func save(_ result: SessionResult) {
        guard let userId = auth.currentUserId, result.totalSeconds > 0 else { return }
        Task {
            try? await FirebaseService.shared.recordSession(
                userId: userId,
                subject: result.subject,
                startTime: result.startedAt,
                totalSeconds: result.totalSeconds,
                targetMinutes: result.targetMinutes,
                postureScore: result.avgPosture,
                focusScore: result.avgFocus,
                postureAlertCount: result.postureAlertCount,
                status: "completed"
            )
        }
    }
}
