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
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Buat Akun")
                    .font(.largeTitle.bold())
                Text("Mulai perjalanan belajar yang lebih sehat.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                TextField("Nama", text: $name)
                    .textContentType(.name)
                    .textFieldStyle(.roundedBorder)

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                SecureField("Kata sandi (min. 6 karakter)", text: $password)
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
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 4)
                } else {
                    Text("Daftar").frame(maxWidth: .infinity).padding(.vertical, 4)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSubmit)

            Button("Sudah punya akun? Masuk", action: onBackToLogin)
                .font(.subheadline)

            Spacer()
        }
        .padding(28)
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView(auth: AuthService(), onBackToLogin: {})
    }
}
