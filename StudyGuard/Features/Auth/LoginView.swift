//
//  LoginView.swift
//  StudyGuard
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var auth: AuthService
    let onRegister: () -> Void

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 6 && !auth.isBusy
    }

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 24)

                    VStack(spacing: 10) {
                        BrandImage(name: "GuriLogo", fallbackSystemName: "graduationcap.fill")
                            .frame(height: 110)
                        Text("Welcome back")
                            .font(.title2.bold())
                            .foregroundStyle(Theme.navy)
                        Text("Sign in to continue your study streak")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }

                    formCard

                    googleButton

                    Button("Don't have an account? Sign Up", action: onRegister)
                        .font(.subheadline)
                        .foregroundStyle(Theme.orange)
                        .padding(.top, 4)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 28)
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            Circle()
                .fill(Theme.orange.opacity(0.12))
                .frame(width: 280, height: 280)
                .offset(x: -140, y: -360)
            Circle()
                .fill(Theme.navy.opacity(0.05))
                .frame(width: 220, height: 220)
                .offset(x: 160, y: 380)
        }
    }

    // MARK: - Form card

    private var formCard: some View {
        VStack(spacing: 16) {
            fieldRow(icon: "envelope.fill", isFocused: focusedField == .email) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
            }

            Divider()

            fieldRow(icon: "lock.fill", isFocused: focusedField == .password) {
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
            }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await auth.signIn(email: email, password: password) }
            } label: {
                if auth.isBusy {
                    ProgressView().tint(.white)
                } else {
                    Text("Sign In")
                }
            }
            .buttonStyle(.sgPrimary)
            .disabled(!canSubmit)
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: Theme.navy.opacity(0.06), radius: 16, y: 8)
    }

    private func fieldRow(icon: String, isFocused: Bool, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(isFocused ? Theme.orange : Theme.muted)
                .frame(width: 20)
            content()
        }
    }

    // MARK: - Google

    private var googleButton: some View {
        VStack(spacing: 16) {
            HStack {
                Rectangle().fill(Theme.navy.opacity(0.12)).frame(height: 1)
                Text("or").font(.caption).foregroundStyle(Theme.muted)
                Rectangle().fill(Theme.navy.opacity(0.12)).frame(height: 1)
            }

            Button {
                Task { await auth.signInWithGoogle() }
            } label: {
                Label("Continue with Google", systemImage: "globe")
                    .font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(Theme.navy)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.navy.opacity(0.15)))
            }
            .disabled(auth.isBusy)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(auth: AuthService(), onRegister: {})
    }
}
