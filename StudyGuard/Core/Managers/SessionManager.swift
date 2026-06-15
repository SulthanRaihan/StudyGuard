//
//  SessionManager.swift
//  StudyGuard
//

import Foundation
import Combine

/// Orchestrates an active study session: owns the camera + posture + focus
/// managers, runs the countdown timer, drives voice coaching, applies the
/// adaptive-timer rules, and tracks session-long average scores.
final class SessionManager: ObservableObject {

    enum Phase {
        case studying
        case finished(reason: EndReason)
    }

    enum EndReason {
        case timerComplete   // reached target duration
        case focusDrop       // adaptive early break
        case userEnded       // user tapped end
    }

    // MARK: - Published state

    @Published private(set) var phase: Phase = .studying
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var avgPosture: Double = 100
    @Published private(set) var avgFocus: Double = 100
    @Published private(set) var postureAlertCount = 0

    // MARK: - Config

    let subject: String
    let targetDuration: Int            // minutes (user's choice)
    private var targetSeconds: Int     // mutable: adaptive timer can extend it

    // MARK: - Owned managers

    let camera = CameraManager()
    let posture = PostureManager()
    let focus = FocusManager()
    private let voice = VoiceAlertService()

    // MARK: - Internals

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var postureSum = 0.0
    private var focusSum = 0.0
    private var sampleCount = 0

    init(subject: String, targetDuration: Int, sensitivity: AlertSensitivity = .medium, voiceLanguage: String = "id-ID") {
        self.subject = subject
        self.targetDuration = targetDuration
        self.targetSeconds = targetDuration * 60
        self.remainingSeconds = targetDuration * 60
        posture.sensitivity = sensitivity
        voice.language = voiceLanguage
    }

    // MARK: - Lifecycle

    func start() {
        camera.start()
        posture.connect(to: camera)
        focus.connect(to: camera)
        observeAlerts()
        startTimer()
    }

    /// Ends the session and releases the camera. `reason` defaults to a user-tap.
    func end(reason: EndReason = .userEnded) {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
        posture.disconnect()
        focus.disconnect()
        camera.stop()
        voice.stop()
        phase = .finished(reason: reason)
    }

    // MARK: - Timer

    private func startTimer() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        elapsedSeconds += 1
        remainingSeconds = max(0, targetSeconds - elapsedSeconds)

        // Accumulate session-long averages from the rolling per-manager scores.
        postureSum += posture.postureScore
        focusSum += focus.focusScore
        sampleCount += 1
        avgPosture = postureSum / Double(sampleCount)
        avgFocus = focusSum / Double(sampleCount)

        if elapsedSeconds % 60 == 0 {
            checkAdaptiveTimer()
        }
        if remainingSeconds == 0 {
            end(reason: .timerComplete)
            voice.announce("Waktunya istirahat! Lakukan peregangan sebentar.")
        }
    }

    /// Adaptive timer: extend when deeply focused at target, break early when
    /// focus collapses, otherwise break on time. Checked once a minute.
    private func checkAdaptiveTimer() {
        let elapsedMinutes = elapsedSeconds / 60
        let recentFocus = focus.focusScore

        if recentFocus > 85, elapsedSeconds >= targetSeconds {
            targetSeconds += 5 * 60
            remainingSeconds = max(0, targetSeconds - elapsedSeconds)
            voice.announce("Kamu lagi fokus banget, perpanjang 5 menit ya!")
        } else if recentFocus < 40, elapsedMinutes > 15 {
            end(reason: .focusDrop)
            voice.announce("Fokus kamu mulai turun, waktunya istirahat sebentar.")
        }
        // Normal on-time break is handled by remainingSeconds hitting 0 in tick().
    }

    // MARK: - Voice coaching

    private func observeAlerts() {
        // Sustained bad posture -> coach + count.
        posture.$activeAlert
            .removeDuplicates()
            .sink { [weak self] alert in
                guard let self, let alert else { return }
                self.postureAlertCount += 1
                self.voice.speak(self.postureMessage(for: alert), key: "posture-\(alert.rawValue)")
            }
            .store(in: &cancellables)

        // Focus state changes -> drowsy / distracted coaching.
        focus.$currentState
            .removeDuplicates()
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .drowsy:
                    self.voice.speak("Kamu terlihat mengantuk, ambil nafas dalam.", key: "drowsy", cooldown: 20)
                case .distracted:
                    self.voice.speak("Fokus kembali ke materi kamu.", key: "distracted", cooldown: 45)
                case .focused:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func postureMessage(for type: PostureType) -> String {
        switch type {
        case .tlf: return "Punggung kamu membungkuk ke depan, perbaiki posisi duduk."
        case .tlb: return "Kamu bersandar terlalu jauh ke belakang."
        case .tlr: return "Kamu miring ke kanan, duduk tegak ya."
        case .tll: return "Kamu miring ke kiri, duduk tegak ya."
        case .tup: return ""
        }
    }
}
