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
