//
//  SessionView.swift
//  StudyGuard
//

import SwiftUI

/// The live study screen: camera feed, real-time posture + focus readouts,
/// countdown timer, and a post-session summary. Driven by `SessionManager`.
struct SessionView: View {
    @ObservedObject private var session: SessionManager
    @ObservedObject private var camera: CameraManager
    @ObservedObject private var posture: PostureManager
    @ObservedObject private var focus: FocusManager

    /// Called with the session's result when the user leaves the finished session.
    let onFinish: (SessionResult) -> Void

    init(session: SessionManager, onFinish: @escaping (SessionResult) -> Void) {
        self.session = session
        self.camera = session.camera
        self.posture = session.posture
        self.focus = session.focus
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            cameraLayer
            overlay
            if case let .finished(reason) = session.phase {
                finishedOverlay(reason: reason)
            }
        }
        .onAppear(perform: start)
        .onDisappear { session.end() }
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
            header
            postureCard
            Spacer()
            HStack(alignment: .bottom, spacing: 12) {
                FocusScoreView(title: "Fokus", score: focus.focusScore, caption: focusCaption)
                FocusScoreView(title: "Postur", score: posture.postureScore, caption: postureCaption)
            }
        }
        .padding()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.subject)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Sisa waktu")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Text(timeString)
                .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Spacer()
            Button(role: .destructive) {
                session.end(reason: .userEnded)
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .padding(10)
                    .background(.red.opacity(0.85), in: Circle())
                    .foregroundStyle(.white)
            }
        }
        .padding(14)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
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

    private var focusCaption: String {
        guard focus.isFaceDetected else { return "Wajah tak terlihat" }
        switch focus.currentState {
        case .focused: return "Fokus"
        case .drowsy: return "Mengantuk"
        case .distracted: return "Teralihkan"
        }
    }

    private var postureCaption: String {
        posture.dominantIssue?.displayName ?? "Tegak"
    }

    // MARK: - Finished overlay

    private func finishedOverlay(reason: SessionManager.EndReason) -> some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                Text("Sesi selesai")
                    .font(.title.bold())
                Text(reasonText(reason))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                HStack(spacing: 28) {
                    stat("Durasi", "\(session.elapsedSeconds / 60) mnt")
                    stat("Postur", "\(Int(session.avgPosture))%")
                    stat("Fokus", "\(Int(session.avgFocus))%")
                }
                .padding(.top, 4)

                Button("Lihat Ringkasan") {
                    onFinish(session.makeResult())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }
            .padding(32)
            .foregroundStyle(.white)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func reasonText(_ reason: SessionManager.EndReason) -> String {
        switch reason {
        case .timerComplete: return "Kerja bagus! Kamu menyelesaikan sesi sesuai target."
        case .focusDrop: return "Fokusmu menurun — saatnya istirahat sejenak."
        case .userEnded: return "Sesi dihentikan."
        }
    }

    private var timeString: String {
        let s = max(0, session.remainingSeconds)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    // MARK: - Lifecycle

    private func start() {
        // Defer past the current SwiftUI update so side-effecting @Published
        // mutations don't fire "within view updates".
        DispatchQueue.main.async {
            switch camera.authorizationState {
            case .authorized:
                session.start()
            case .notDetermined:
                camera.requestAccess { granted in
                    guard granted else { return }
                    session.start()
                }
            case .denied:
                break
            }
        }
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
        SessionView(session: SessionManager(subject: "Matematika", targetDuration: 25)) { _ in }
    }
}
