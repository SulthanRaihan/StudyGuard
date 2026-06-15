//
//  AuthService.swift
//  StudyGuard
//

import Foundation
import FirebaseAuth

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

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
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
