//
//  RegisterView.swift
//  StudyGuard
//

import SwiftUI

struct RegisterView: View {
    @ObservedObject var auth: AuthService
    let onBackToLogin: () -> Void

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @SwiftUI.FocusState private var focusedField: Field?

    private enum Field { case name, email, password }

    private var canSubmit: Bool {
        !name.isEmpty && !email.isEmpty && password.count >= 6 && !auth.isBusy
    }

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 24)

                    VStack(spacing: 10) {
                        BrandImage(name: "GuriHi", fallbackSystemName: "graduationcap.fill")
                            .frame(height: 100)
                        Text("Create Account")
                            .font(.title2.bold())
                            .foregroundStyle(Theme.navy)
                        Text("Start your healthier study journey.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }

                    formCard

                    googleButton

                    Button("Already have an account? Sign In", action: onBackToLogin)
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
                .offset(x: 150, y: -380)
            Circle()
                .fill(Theme.navy.opacity(0.05))
                .frame(width: 220, height: 220)
                .offset(x: -160, y: 400)
        }
    }

    // MARK: - Form card

    private var formCard: some View {
        VStack(spacing: 16) {
            fieldRow(icon: "person.fill", isFocused: focusedField == .name) {
                TextField("Name", text: $name)
                    .textContentType(.name)
                    .focused($focusedField, equals: .name)
            }

            Divider()

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
                SecureField("Password (min. 6 characters)", text: $password)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
            }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await auth.register(name: name, email: email, password: password) }
            } label: {
                if auth.isBusy {
                    ProgressView().tint(.white)
                } else {
                    Text("Sign Up")
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

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView(auth: AuthService(), onBackToLogin: {})
    }
}
