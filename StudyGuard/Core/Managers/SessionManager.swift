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
        case calibrating
        case studying
        case paused
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
    @Published private(set) var distractionCount = 0

    // MARK: - Config

    let subject: String
    let targetDuration: Int            // minutes (user's choice)
    private(set) var startedAt = Date()
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
    private var focusTimeline: [Int] = []   // per-minute focus score, for the Groq summary

    init(subject: String, targetDuration: Int, sensitivity: AlertSensitivity = .medium,
         voiceLanguage: String = "en-US", voiceEnabled: Bool = true) {
        self.subject = subject
        self.targetDuration = targetDuration
        self.targetSeconds = targetDuration * 60
        self.remainingSeconds = targetDuration * 60
        posture.sensitivity = sensitivity
        voice.language = voiceLanguage
        voice.isEnabled = voiceEnabled
    }

    // MARK: - Lifecycle

    func start() {
        startedAt = Date()
        camera.start()
        posture.connect(to: camera)
        focus.connect(to: camera)

        // Calibrate the user's upright posture before the clock starts.
        phase = .calibrating
        posture.calibrate(seconds: 4) { [weak self] in
            guard let self, case .calibrating = self.phase else { return }
            self.startedAt = Date()
            self.observeAlerts()
            self.startTimer()
            self.phase = .studying
        }
    }

    /// Pauses the session: camera + detectors + timer stop, but the session is
    /// not finished (the user can resume or take a break).
    func pause() {
        guard case .studying = phase else { return }
        timer?.invalidate()
        timer = nil
        posture.disconnect()
        focus.disconnect()
        camera.pause()
        voice.stop()
        phase = .paused
    }

    /// Resumes a paused session.
    func resume() {
        guard case .paused = phase else { return }
        camera.resume()
        posture.connect(to: camera)
        focus.connect(to: camera)
        observeAlerts()
        startTimer()
        phase = .studying
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

    /// Snapshot of the finished session for the summary, break, and persistence.
    func makeResult() -> SessionResult {
        SessionResult(
            subject: subject,
            totalSeconds: elapsedSeconds,
            targetMinutes: targetDuration,
            avgPosture: avgPosture,
            avgFocus: avgFocus,
            postureAlertCount: postureAlertCount,
            distractionCount: distractionCount,
            dominantIssue: posture.dominantIssue,
            focusTimeline: focusTimeline,
            startedAt: startedAt
        )
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
            focusTimeline.append(Int(focus.focusScore))
            checkAdaptiveTimer()
        }
        // Periodic wellness reminders (voice).
        if elapsedSeconds > 0 {
            if elapsedSeconds % (20 * 60) == 0 {
                voice.speak("Time to rest your eyes — look at something far away for 20 seconds.",
                            key: "eye-rest", cooldown: 60)
            }
            if elapsedSeconds % (30 * 60) == 0 {
                voice.speak("Don't forget to drink some water!", key: "water", cooldown: 60)
            }
        }
        if remainingSeconds == 0 {
            end(reason: .timerComplete)
            voice.announce("Time's up! Great work — your session is complete.")
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
            voice.announce("You're in deep focus — let's add 5 more minutes!")
        } else if recentFocus < 40, elapsedMinutes > 15 {
            end(reason: .focusDrop)
            voice.announce("Your focus is dropping — let's wrap up this session.")
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
                    self.voice.speak("You look drowsy — take a deep breath.", key: "drowsy", cooldown: 20)
                case .distracted:
                    self.distractionCount += 1
                    self.voice.speak("Let's get back to your study material.", key: "distracted", cooldown: 45)
                case .focused:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func postureMessage(for type: PostureType) -> String {
        switch type {
        case .tlf: return "You're slouching forward — sit up straight."
        case .tlb: return "You're leaning too far back."
        case .tlr: return "You're tilting to the right — straighten up."
        case .tll: return "You're tilting to the left — straighten up."
        case .tup: return ""
        }
    }
}
