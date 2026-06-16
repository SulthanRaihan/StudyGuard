//
//  AuthService.swift
//  StudyGuard
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

/// Wraps Firebase Authentication and exposes the current auth state to SwiftUI.
@MainActor
final class AuthService: ObservableObject {

    @Published private(set) var currentUserId: String?
    @Published private(set) var displayName: String?
    @Published var errorMessage: String?
    @Published var isBusy = false

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUserId = user?.uid
                self?.displayName = user?.displayName
            }
        }
    }

    var isAuthenticated: Bool { currentUserId != nil }

    func signIn(email: String, password: String) async {
        isBusy = true; errorMessage = nil
        do {
            _ = try await Auth.auth().signIn(withEmail: email.trimmed, password: password)
        } catch {
            errorMessage = message(for: error)
        }
        isBusy = false
    }

    func register(name: String, email: String, password: String) async {
        isBusy = true; errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email.trimmed, password: password)
            let change = result.user.createProfileChangeRequest()
            change.displayName = name
            try await change.commitChanges()
            displayName = name
            try await FirebaseService.shared.createUserProfile(
                userId: result.user.uid, name: name, email: email.trimmed
            )
        } catch {
            errorMessage = message(for: error)
        }
        isBusy = false
    }

    func signInWithGoogle() async {
        isBusy = true; errorMessage = nil
        defer { isBusy = false }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Google Sign-In is not configured."
            return
        }
        guard let presenter = Self.topViewController() else {
            errorMessage = "Couldn't present Google Sign-In."
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Missing Google ID token."
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let authResult = try await Auth.auth().signIn(with: credential)
            if authResult.additionalUserInfo?.isNewUser == true {
                let name = result.user.profile?.name ?? authResult.user.displayName ?? "Learner"
                try? await FirebaseService.shared.createUserProfile(
                    userId: authResult.user.uid, name: name, email: authResult.user.email ?? ""
                )
            }
        } catch let error as NSError where error.code == GIDSignInError.canceled.rawValue {
            // User cancelled — not an error worth showing.
        } catch {
            errorMessage = message(for: error)
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The top-most view controller, to present the Google sign-in sheet from.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController
            ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    /// Maps the most common Firebase auth errors to friendly Indonesian copy.
    private func message(for error: Error) -> String {
        guard let code = AuthErrorCode.Code(rawValue: (error as NSError).code) else {
            return error.localizedDescription
        }
        switch code {
        case .invalidEmail: return "Format email tidak valid."
        case .wrongPassword, .invalidCredential: return "Email atau kata sandi salah."
        case .userNotFound: return "Akun tidak ditemukan."
        case .emailAlreadyInUse: return "Email sudah terdaftar."
        case .weakPassword: return "Kata sandi minimal 6 karakter."
        case .networkError: return "Masalah jaringan, coba lagi."
        default: return error.localizedDescription
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
