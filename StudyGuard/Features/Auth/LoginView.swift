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
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "figure.mind.and.body")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("StudyGuard")
                    .font(.largeTitle.bold())
                Text("Teman belajar yang menjaga postur & fokusmu.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                SecureField("Kata sandi", text: $password)
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
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 4)
                } else {
                    Text("Masuk").frame(maxWidth: .infinity).padding(.vertical, 4)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSubmit)

            Button("Belum punya akun? Daftar", action: onRegister)
                .font(.subheadline)

            Spacer()
        }
        .padding(28)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(auth: AuthService(), onRegister: {})
    }
}
