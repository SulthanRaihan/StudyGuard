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

    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 6 && !auth.isBusy
    }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 10) {
                    BrandImage(name: "GuriLogo", fallbackSystemName: "graduationcap.fill")
                        .frame(height: 130)
                    Text("Welcome back")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }

                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
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

                Button("Don't have an account? Sign Up", action: onRegister)
                    .font(.subheadline)
                    .foregroundStyle(Theme.orange)

                Spacer()
            }
            .padding(28)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(auth: AuthService(), onRegister: {})
    }
}
