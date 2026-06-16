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

    private var canSubmit: Bool {
        !name.isEmpty && !email.isEmpty && password.count >= 6 && !auth.isBusy
    }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 10) {
                    BrandImage(name: "GuriHi", fallbackSystemName: "graduationcap.fill")
                        .frame(height: 100)
                    Text("Create Account")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Theme.navy)
                    Text("Start your healthier study journey.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }

                VStack(spacing: 14) {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .textFieldStyle(.roundedBorder)

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password (min. 6 characters)", text: $password)
                        .textContentType(.newPassword)
                        .textFieldStyle(.roundedBorder)

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
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

                Button("Already have an account? Sign In", action: onBackToLogin)
                    .font(.subheadline)
                    .foregroundStyle(Theme.orange)

                Spacer()
            }
            .padding(28)
        }
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView(auth: AuthService(), onBackToLogin: {})
    }
}
