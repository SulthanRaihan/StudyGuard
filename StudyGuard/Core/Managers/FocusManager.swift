//
//  FocusManager.swift
//  StudyGuard
//

import Foundation
import Combine
import AVFoundation
import ImageIO   // CGImagePropertyOrientation

/// Drives focus detection during a session: subscribes to camera frames, runs
/// `FocusDetector` (throttled, dropping frames while busy), applies temporal
/// thresholds (a blink isn't drowsiness; a glance isn't distraction), and keeps
/// a rolling 60-second focus score.
///
/// `@Published` properties are updated on the main queue; internal state is
/// confined to `inferenceQueue`.
final class FocusManager: ObservableObject {

    // MARK: - Published UI state

    @Published private(set) var currentState: FocusState = .focused
    @Published private(set) var focusScore: Double = 100   // % focused in last 60s
    @Published private(set) var isFaceDetected = false
    /// Smoothed face width (distance proxy); larger = leaning closer to the screen.
    @Published private(set) var faceWidth: Double = 0

    private var faceWidthEMA: Double = 0

    // MARK: - Temporal thresholds

    private let drowsySeconds: TimeInterval = 3.0       // closed eyes this long = drowsy
    private let distractedSeconds: TimeInterval = 1.5   // looking away this long = distracted

    // MARK: - Inference plumbing

    private let detector = FocusDetector()
    private let inferenceQueue = DispatchQueue(label: "com.studyguard.focus.inference")
    private var cancellable: AnyCancellable?

    /// Front camera, portrait, un-mirrored data output -> upright image for Vision.
    private let orientation: CGImagePropertyOrientation = .up

    private let gate = NSLock()
    private var isProcessing = false
    private var lastInference = Date.distantPast
    private let minInterval: TimeInterval = 0.2   // ~5 inferences/sec

    // MARK: - State (inferenceQueue only)

    private var eyesClosedSince: Date?
    private var lookingAwaySince: Date?

    private struct Sample { let time: Date; let focused: Bool }
    private var window: [Sample] = []
    private let windowSeconds: TimeInterval = 60

    // MARK: - Lifecycle

    func connect(to camera: CameraManager) {
        cancellable = camera.framePublisher.sink { [weak self] sample in
            self?.enqueue(sample)
        }
    }

    func disconnect() {
        cancellable = nil
        inferenceQueue.async { [weak self] in
            self?.window.removeAll()
            self?.eyesClosedSince = nil
            self?.lookingAwaySince = nil
        }
        gate.lock(); isProcessing = false; lastInference = .distantPast; gate.unlock()
        publish(state: .focused, score: 100, faceDetected: false)
    }

    // MARK: - Frame intake (camera queue)

    private func enqueue(_ sample: CMSampleBuffer) {
        let now = Date()
        gate.lock()
        let shouldDrop = isProcessing || now.timeIntervalSince(lastInference) < minInterval
        if shouldDrop {
            gate.unlock()
            return
        }
        isProcessing = true
        lastInference = now
        gate.unlock()

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else {
            gate.lock(); isProcessing = false; gate.unlock()
            return
        }

        inferenceQueue.async { [weak self] in
            self?.run(pixelBuffer, retaining: sample)
        }
    }

    // MARK: - Inference (inferenceQueue)

    private func run(_ pixelBuffer: CVPixelBuffer, retaining sample: CMSampleBuffer) {
        defer {
            gate.lock(); isProcessing = false; gate.unlock()
        }

        let signals = try? detector.detectFocus(in: pixelBuffer, orientation: orientation)
        let now = Date()

        guard let signals else {
            // No face -> user is away from the screen: distracted.
            eyesClosedSince = nil
            lookingAwaySince = lookingAwaySince ?? now
            recordAndPublish(state: .distracted, now: now, faceDetected: false)
            return
        }

        // Track sustained eye-closure and look-away.
        eyesClosedSince = signals.eyesClosed ? (eyesClosedSince ?? now) : nil
        lookingAwaySince = signals.lookingAway ? (lookingAwaySince ?? now) : nil

        // Smooth the face-width distance proxy.
        faceWidthEMA = faceWidthEMA == 0 ? signals.faceWidth : (0.7 * faceWidthEMA + 0.3 * signals.faceWidth)

        let state = resolveState(now: now)
        recordAndPublish(state: state, now: now, faceDetected: true)
    }

    /// Distraction takes priority over drowsiness; a brief blink/glance stays focused.
    private func resolveState(now: Date) -> FocusState {
        if let away = lookingAwaySince, now.timeIntervalSince(away) >= distractedSeconds {
            return .distracted
        }
        if let closed = eyesClosedSince, now.timeIntervalSince(closed) >= drowsySeconds {
            return .drowsy
        }
        return .focused
    }

    private func recordAndPublish(state: FocusState, now: Date, faceDetected: Bool) {
        window.append(Sample(time: now, focused: state == .focused))
        pruneWindow(now: now)
        publish(state: state, score: currentScore(), faceDetected: faceDetected, faceWidth: faceWidthEMA)
    }

    // MARK: - Scoring (inferenceQueue)

    private func pruneWindow(now: Date) {
        let cutoff = now.addingTimeInterval(-windowSeconds)
        if let first = window.first, first.time < cutoff {
            window.removeAll { $0.time < cutoff }
        }
    }

    private func currentScore() -> Double {
        guard !window.isEmpty else { return 100 }
        let focused = window.lazy.filter(\.focused).count
        return (Double(focused) / Double(window.count)) * 100
    }

    // MARK: - Publishing

    private func publish(state: FocusState, score: Double, faceDetected: Bool, faceWidth: Double = 0) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentState = state
            self.focusScore = score
            self.isFaceDetected = faceDetected
            self.faceWidth = faceWidth
        }
    }
}
