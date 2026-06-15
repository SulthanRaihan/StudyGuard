//
//  OnboardingView.swift
//  StudyGuard
//

import SwiftUI

/// Welcome screen shown before authentication.
struct OnboardingView: View {
    let onSignUp: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()

                BrandImage(name: "GuriLogo", fallbackSystemName: "graduationcap.fill")
                    .frame(height: 200)

                VStack(spacing: 10) {
                    Text("Start Your Journey Today")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Theme.navy)
                        .multilineTextAlignment(.center)
                    Text("StudyGuard watches your posture and focus in real time, coaches you, and tracks your progress — like a fitness app for studying.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)

                Spacer()

                VStack(spacing: 12) {
                    Button("Sign Up", action: onSignUp)
                        .buttonStyle(.sgPrimary)
                    Button("Sign In", action: onSignIn)
                        .buttonStyle(.sgSecondary)
                }
            }
            .padding(28)
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onSignUp: {}, onSignIn: {})
    }
}
