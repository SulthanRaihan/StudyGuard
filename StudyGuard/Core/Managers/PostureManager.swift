//
//  PostureManager.swift
//  StudyGuard
//

import Foundation
import Combine
import AVFoundation
import ImageIO   // CGImagePropertyOrientation

/// Drives posture classification during a session: subscribes to camera frames,
/// runs `PostureDetector` (throttled, dropping frames while busy), maintains a
/// rolling 60-second window for scoring, and tracks sustained bad-posture alerts.
///
/// `@Published` properties are always updated on the main queue. Internal scoring
/// state is confined to `inferenceQueue`.
final class PostureManager: ObservableObject {

    // MARK: - Published UI state

    @Published private(set) var currentPosture: PostureType?
    @Published private(set) var currentConfidence: Double = 0
    @Published private(set) var postureScore: Double = 100   // % good frames in last 60s
    @Published private(set) var dominantIssue: PostureType?
    @Published private(set) var isBodyDetected = false
    /// Set to the offending posture once it has been sustained past the
    /// sensitivity threshold; `nil` while posture is acceptable.
    @Published private(set) var activeAlert: PostureType?

    /// Alert sensitivity (seconds of sustained bad posture before alerting).
    var sensitivity: AlertSensitivity = .medium

    // MARK: - Inference plumbing

    private let detector: PostureDetector?
    private let inferenceQueue = DispatchQueue(label: "com.studyguard.posture.inference")
    private var cancellable: AnyCancellable?

    /// Front camera, portrait, un-mirrored data output -> upright image for Vision.
    private let orientation: CGImagePropertyOrientation = .up

    // Frame-drop gate (touched from the camera queue and the inference queue).
    private let gate = NSLock()
    private var isProcessing = false
    private var lastInference = Date.distantPast
    private let minInterval: TimeInterval = 0.2   // cap at ~5 inferences/sec

    // MARK: - Smoothing config

    /// Per-frame predictions jitter; we report a posture only after it dominates a
    /// short window, so small movements don't flicker the label (or trigger voice).
    private let minConfidence: Double = 0.30        // ignore weak predictions
    private let smoothingWindow: TimeInterval = 1.2 // majority-vote horizon
    private let switchThreshold: Double = 0.60      // share of window needed to switch

    // MARK: - Scoring state (inferenceQueue only)

    private struct Raw { let time: Date; let type: PostureType; let confidence: Double }
    private var rawHistory: [Raw] = []
    private var stableType: PostureType?

    private struct Sample { let time: Date; let isGood: Bool; let type: PostureType }
    private var window: [Sample] = []
    private let windowSeconds: TimeInterval = 60

    private var badSince: Date?
    private var badType: PostureType?

    // Per-user calibration: the class the model predicts when the user sits upright.
    // The model confuses upright (TUP) with slouching (TLF); learning the user's own
    // "neutral" prediction lets us treat it as good and avoid false slouch alerts.
    private var calibrating = false
    private var calibrationVotes: [PostureType: Int] = [:]
    private var baselineClass: PostureType?

    init() {
        detector = try? PostureDetector()
    }

    /// Collects the model's predictions for `seconds` (user sitting upright), then
    /// records the most common one as the user's neutral posture. `completion` runs
    /// on the main queue.
    func calibrate(seconds: TimeInterval, completion: @escaping () -> Void) {
        inferenceQueue.async { [weak self] in
            self?.calibrationVotes = [:]
            self?.baselineClass = nil
            self?.calibrating = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self else { completion(); return }
            self.inferenceQueue.async {
                self.calibrating = false
                self.baselineClass = self.calibrationVotes.max { $0.value < $1.value }?.key
                DispatchQueue.main.async(execute: completion)
            }
        }
    }

    /// Remaps the user's neutral class to "upright" so it isn't flagged as bad.
    private func normalized(_ type: PostureType) -> PostureType {
        if let baselineClass, type == baselineClass { return .tup }
        return type
    }

    var isModelReady: Bool { detector != nil }

    // MARK: - Lifecycle

    /// Begin classifying frames from `camera`.
    func connect(to camera: CameraManager) {
        cancellable = camera.framePublisher.sink { [weak self] sample in
            self?.enqueue(sample)
        }
    }

    /// Stop classifying and reset all state.
    func disconnect() {
        cancellable = nil
        inferenceQueue.async { [weak self] in
            self?.window.removeAll()
            self?.rawHistory.removeAll()
            self?.stableType = nil
            self?.badSince = nil
            self?.badType = nil
            self?.calibrating = false
            self?.calibrationVotes = [:]
            // baselineClass is kept so calibration survives pause/resume.
        }
        gate.lock(); isProcessing = false; lastInference = .distantPast; gate.unlock()
        publish(posture: nil, confidence: 0, bodyDetected: false, score: 100, dominant: nil, alert: nil)
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

        // Retain `sample` in the closure so the pixel buffer stays valid off-queue.
        inferenceQueue.async { [weak self] in
            self?.run(pixelBuffer, retaining: sample)
        }
    }

    // MARK: - Inference (inferenceQueue)

    private func run(_ pixelBuffer: CVPixelBuffer, retaining sample: CMSampleBuffer) {
        defer {
            gate.lock(); isProcessing = false; gate.unlock()
        }
        guard let detector else { return }

        let result: PostureResult? = try? detector.detectPosture(in: pixelBuffer, orientation: orientation)
        let now = Date()

        guard let result else {
            // No body detected — leave scoring/history untouched, keep last stable label.
            publish(posture: stableType, confidence: 0, bodyDetected: false,
                    score: currentScore(), dominant: currentDominant(), alert: nil)
            return
        }

        // During calibration, just tally the raw predictions; don't score/alert.
        if calibrating {
            if result.confidence >= minConfidence {
                calibrationVotes[result.type, default: 0] += 1
            }
            publish(posture: .tup, confidence: result.confidence, bodyDetected: true,
                    score: 100, dominant: nil, alert: nil)
            return
        }

        // Feed confident predictions (remapped through the user's baseline) into the
        // smoothing history, then resolve a stable posture by majority vote.
        if result.confidence >= minConfidence {
            rawHistory.append(Raw(time: now, type: normalized(result.type), confidence: result.confidence))
        }
        pruneRawHistory(now: now)
        stableType = smoothedPosture()

        if let stable = stableType {
            window.append(Sample(time: now, isGood: stable.isGood, type: stable))
            pruneWindow(now: now)
        }

        let alert = stableType.flatMap { updateAlert(for: $0, now: now) }

        publish(posture: stableType,
                confidence: smoothedConfidence(for: stableType),
                bodyDetected: true,
                score: currentScore(),
                dominant: currentDominant(),
                alert: alert)
    }

    // MARK: - Temporal smoothing (inferenceQueue)

    private func pruneRawHistory(now: Date) {
        let cutoff = now.addingTimeInterval(-smoothingWindow)
        rawHistory.removeAll { $0.time < cutoff }
    }

    /// Majority class over the recent window. Switches the reported posture only
    /// when a challenger reaches `switchThreshold`; otherwise the current stable
    /// posture sticks (hysteresis). Reports immediately at startup.
    private func smoothedPosture() -> PostureType? {
        guard !rawHistory.isEmpty else { return stableType }
        let counts = Dictionary(grouping: rawHistory, by: { $0.type }).mapValues(\.count)
        guard let top = counts.max(by: { $0.value < $1.value }) else { return stableType }
        if top.key == stableType { return stableType }
        let share = Double(top.value) / Double(rawHistory.count)
        return share >= switchThreshold ? top.key : (stableType ?? top.key)
    }

    private func smoothedConfidence(for type: PostureType?) -> Double {
        guard let type else { return 0 }
        let matching = rawHistory.filter { $0.type == type }
        guard !matching.isEmpty else { return 0 }
        return matching.map(\.confidence).reduce(0, +) / Double(matching.count)
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
        let good = window.lazy.filter { $0.isGood }.count
        return (Double(good) / Double(window.count)) * 100
    }

    /// Most frequent bad posture in the window, or `nil` if posture is mostly good.
    private func currentDominant() -> PostureType? {
        let bad = window.filter { !$0.isGood }
        guard !bad.isEmpty else { return nil }
        let counts = Dictionary(grouping: bad, by: { $0.type }).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key
    }

    // MARK: - Alert tracking (inferenceQueue)

    private func updateAlert(for type: PostureType, now: Date) -> PostureType? {
        guard !type.isGood else {
            badSince = nil
            badType = nil
            return nil
        }
        if badType != type {
            badType = type
            badSince = now
        }
        let elapsed = now.timeIntervalSince(badSince ?? now)
        return elapsed >= Double(sensitivity.thresholdSeconds) ? type : nil
    }

    // MARK: - Publishing

    private func publish(posture: PostureType?, confidence: Double, bodyDetected: Bool,
                         score: Double, dominant: PostureType?, alert: PostureType?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentPosture = posture
            self.currentConfidence = confidence
            self.isBodyDetected = bodyDetected
            self.postureScore = score
            self.dominantIssue = dominant
            self.activeAlert = alert
        }
    }
}
