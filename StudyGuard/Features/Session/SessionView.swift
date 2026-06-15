//
//  SessionView.swift
//  StudyGuard
//

import SwiftUI

/// The live study screen (Milestone 1 scope): camera feed + real-time posture
/// classification label and score. Focus, timer, voice alerts, and persistence
/// arrive in later milestones.
struct SessionView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var posture = PostureManager()

    var body: some View {
        ZStack {
            cameraLayer
            overlay
        }
        .onAppear(perform: start)
        .onDisappear(perform: stop)
    }

    // MARK: - Camera layer

    @ViewBuilder
    private var cameraLayer: some View {
        switch camera.authorizationState {
        case .authorized:
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()
        case .notDetermined:
            Color.black.ignoresSafeArea()
        case .denied:
            permissionDenied
        }
    }

    private var permissionDenied: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("Akses kamera dibutuhkan")
                    .font(.headline)
                Text("Aktifkan kamera di Pengaturan untuk memulai sesi belajar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Buka Pengaturan") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(40)
            .foregroundStyle(.white)
        }
    }

    // MARK: - Overlay

    private var overlay: some View {
        VStack {
            postureCard
            Spacer()
            scoreBadge
        }
        .padding()
    }

    private var postureCard: some View {
        VStack(spacing: 6) {
            if posture.isBodyDetected, let type = posture.currentPosture {
                Label(type.displayName, systemImage: type.iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(type.isGood ? .green : .orange)
                Text("Keyakinan \(Int(posture.currentConfidence * 100))%")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Label("Mencari tubuh…", systemImage: "figure.stand")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut(duration: 0.2), value: posture.currentPosture)
    }

    private var scoreBadge: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Skor Postur")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Text("\(Int(posture.postureScore))%")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
            }
            Spacer()
            if let issue = posture.dominantIssue {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Masalah utama")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(issue.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(16)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
    }

    private var scoreColor: Color {
        switch posture.postureScore {
        case 80...: return .green
        case 50..<80: return .yellow
        default: return .orange
        }
    }

    // MARK: - Lifecycle

    private func start() {
        switch camera.authorizationState {
        case .authorized:
            camera.start()
            posture.connect(to: camera)
        case .notDetermined:
            camera.requestAccess { granted in
                if granted {
                    camera.start()
                    posture.connect(to: camera)
                }
            }
        case .denied:
            break
        }
    }

    private func stop() {
        posture.disconnect()
        camera.stop()
    }
}

// MARK: - Display helpers

private extension PostureType {
    /// Indonesian label shown to the user.
    var displayName: String {
        switch self {
        case .tup: return "Postur tegak"
        case .tlf: return "Membungkuk ke depan"
        case .tlb: return "Bersandar ke belakang"
        case .tlr: return "Miring ke kanan"
        case .tll: return "Miring ke kiri"
        }
    }

    var iconName: String {
        switch self {
        case .tup: return "figure.stand"
        case .tlf: return "figure.walk.motion"
        case .tlb: return "figure.seated.side"
        case .tlr: return "arrow.right"
        case .tll: return "arrow.left"
        }
    }
}

struct SessionView_Previews: PreviewProvider {
    static var previews: some View {
        SessionView()
    }
}
