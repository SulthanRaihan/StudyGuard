//
//  ContentView.swift
//  StudyGuard
//

import SwiftUI

/// Root router: gates on auth state, then hands off to the main tab experience.
struct ContentView: View {
    @StateObject private var auth = AuthService()

    var body: some View {
        if auth.isAuthenticated {
            MainView(auth: auth)
        } else {
            AuthFlow(auth: auth)
        }
    }
}

/// Onboarding -> login / registration.
private struct AuthFlow: View {
    @ObservedObject var auth: AuthService
    @State private var screen: Screen = .onboarding

    private enum Screen { case onboarding, login, register }

    var body: some View {
        switch screen {
        case .onboarding:
            OnboardingView(onSignUp: { screen = .register }, onSignIn: { screen = .login })
        case .login:
            LoginView(auth: auth) { screen = .register }
        case .register:
            RegisterView(auth: auth) { screen = .login }
        }
    }
}
