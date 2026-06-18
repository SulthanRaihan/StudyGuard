//
//  SessionView.swift
//  StudyGuard
//

import SwiftUI

/// The live study screen: camera feed, real-time posture + focus readouts,
/// countdown timer, pause→break flow, and a post-session summary handoff.
struct SessionView: View {
    @ObservedObject private var session: SessionManager
    @ObservedObject private var camera: CameraManager
    @ObservedObject private var posture: PostureManager
    @ObservedObject private var focus: FocusManager
    @ObservedObject private var sound = FocusSoundService.shared

    /// Called with the session's result when the user leaves the finished session.
    let onFinish: (SessionResult) -> Void

    @State private var showBreak = false
    @State private var showSkeleton = true

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
            if showSkeleton, posture.isBodyDetected {
                PostureOverlayView(joints: posture.joints).ignoresSafeArea()
            }
            overlay
            if case .calibrating = session.phase { calibratingOverlay }
            if case .paused = session.phase { pausedOverlay }
            if case let .finished(reason) = session.phase { finishedOverlay(reason: reason) }
        }
        .onAppear(perform: start)
        .onDisappear {
            session.end()
            sound.stop()
        }
        .fullScreenCover(isPresented: $showBreak) {
            BreakView(result: session.makeResult(), isMidSession: true, userId: session.userId) {
                showBreak = false
                session.resume()
            }
        }
    }

    // MARK: - Camera layer

    @ViewBuilder
    private var cameraLayer: some View {
        switch camera.authorizationState {
        case .authorized:
            CameraPreviewView(session: camera.session).ignoresSafeArea()
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
                Image(systemName: "camera.fill").font(.system(size: 44)).foregroundStyle(.secondary)
                Text("Camera access needed").font(.headline)
                Text("Enable the camera in Settings to start a study session.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(40).foregroundStyle(.white)
        }
    }

    // MARK: - Live overlay

    private var overlay: some View {
        VStack {
            header
            postureCard
            Spacer()
            HStack(alignment: .bottom, spacing: 12) {
                FocusScoreView(title: "Focus", score: focus.focusScore, caption: focusCaption)
                FocusScoreView(title: "Posture", score: posture.postureScore, caption: postureCaption)
            }
        }
        .padding()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.subject).font(.headline).foregroundStyle(.white)
                Text("Time left").font(.caption2).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Text(timeString)
                .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Spacer()
            Button {
                showSkeleton.toggle()
            } label: {
                Image(systemName: showSkeleton ? "figure.walk.circle.fill" : "figure.walk.circle")
                    .font(.title3)
                    .padding(10)
                    .background((showSkeleton ? Theme.orange : .white.opacity(0.18)), in: Circle())
                    .foregroundStyle(.white)
            }
            Button {
                sound.toggle()
            } label: {
                Image(systemName: sound.isPlaying ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.title3)
                    .padding(10)
                    .background(.white.opacity(0.18), in: Circle())
                    .foregroundStyle(.white)
            }
            Button {
                session.pause()
            } label: {
                Image(systemName: "pause.fill")
                    .font(.title3)
                    .padding(10)
                    .background(Theme.orange, in: Circle())
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
                Text("Confidence \(Int(posture.currentConfidence * 100))%")
                    .font(.caption).foregroundStyle(.white.opacity(0.8))
            } else {
                Label("Looking for you…", systemImage: "figure.stand")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 20)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut(duration: 0.2), value: posture.currentPosture)
    }

    private var focusCaption: String {
        guard focus.isFaceDetected else { return "No face" }
        switch focus.currentState {
        case .focused: return "Focused"
        case .drowsy: return "Drowsy"
        case .distracted: return "Distracted"
        }
    }

    private var postureCaption: String {
        posture.dominantIssue?.displayName ?? "Upright"
    }

    // MARK: - Calibrating overlay

    private var calibratingOverlay: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 18) {
                BrandImage(name: "GuriHi", fallbackSystemName: "figure.stand")
                    .frame(height: 110)
                ProgressView().tint(.white).scaleEffect(1.3)
                Text("Calibrating…")
                    .font(.title2.bold()).foregroundStyle(.white)
                Text("Sit up straight and look at the screen.\nThis helps Guri learn your good posture.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        }
    }

    // MARK: - Paused overlay

    private var pausedOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "pause.circle.fill").font(.system(size: 56)).foregroundStyle(Theme.orange)
                Text("Session paused").font(.title2.bold()).foregroundStyle(.white)
                Text("Resume when you're ready, or take a quick break.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Button { session.resume() } label: {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .buttonStyle(.sgPrimary)

                    Button { showBreak = true } label: {
                        Label("Take a break", systemImage: "cup.and.saucer.fill")
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }

                    Button(role: .destructive) {
                        session.end(reason: .userEnded)
                    } label: {
                        Text("End session").frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .foregroundStyle(.red)
                }
                .padding(.top, 4)
            }
            .padding(32)
        }
    }

    // MARK: - Finished overlay (no break — done means done)

    private func finishedOverlay(reason: SessionManager.EndReason) -> some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 18) {
                BrandImage(name: "GuriCelebrate", fallbackSystemName: "checkmark.circle.fill")
                    .frame(height: 130)
                Text("Session complete!").font(.title.bold())
                Text(reasonText(reason))
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)

                HStack(spacing: 28) {
                    stat("Duration", "\(session.elapsedSeconds / 60)m")
                    stat("Posture", "\(Int(session.avgPosture))%")
                    stat("Focus", "\(Int(session.avgFocus))%")
                }
                .padding(.top, 4)

                Button("View Summary") { onFinish(session.makeResult()) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
            }
            .padding(32).foregroundStyle(.white)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.7))
        }
    }

    private func reasonText(_ reason: SessionManager.EndReason) -> String {
        switch reason {
        case .timerComplete: return "Great work! You hit your target."
        case .focusDrop: return "Focus was dropping — time to rest."
        case .userEnded: return "Session ended."
        }
    }

    private var timeString: String {
        let s = max(0, session.remainingSeconds)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    // MARK: - Lifecycle

    private func start() {
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
    var displayName: String {
        switch self {
        case .tup: return "Upright posture"
        case .tlf: return "Slouching forward"
        case .tlb: return "Leaning back"
        case .tlr: return "Tilting right"
        case .tll: return "Tilting left"
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
        SessionView(session: SessionManager(subject: "Mathematics", targetDuration: 25)) { _ in }
    }
}
