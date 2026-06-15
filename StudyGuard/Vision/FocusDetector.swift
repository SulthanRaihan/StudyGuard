//
//  FocusDetector.swift
//  StudyGuard
//

import Vision
import CoreVideo

/// Per-frame focus signals derived from face landmarks. Temporal interpretation
/// (e.g. "drowsy after 3s of closed eyes") happens in `FocusManager`.
struct FocusSignals {
    /// Eye openness ratio (height / width), averaged over both eyes.
    /// ~0.3+ = open, < ~0.18 = closing.
    let eyeOpenness: Double
    let yaw: Double            // radians; head turned left/right
    let pitch: Double          // radians; head tilted up/down
    let eyesClosed: Bool       // instantaneous (a single closed frame = a blink)
    let lookingAway: Bool      // instantaneous head turn away from screen
}

/// Detects the user's face with Apple Vision and extracts focus-related signals
/// (eye openness for drowsiness, head pose for gaze-away). No custom model.
final class FocusDetector {

    /// Below this eye-openness ratio the eyes are considered closed.
    private let eyesClosedThreshold = 0.18
    /// Beyond these head angles (radians) the user is considered looking away.
    private let yawAwayThreshold = 0.50    // ~29°
    private let pitchAwayThreshold = 0.65  // ~37°

    /// Returns focus signals, or `nil` if no face is found (user away / turned fully).
    func detectFocus(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> FocusSignals? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        try handler.perform([request])

        guard let face = request.results?.first else { return nil }

        let openness = eyeOpenness(face.landmarks)
        let yaw = face.yaw?.doubleValue ?? 0
        let pitch = face.pitch?.doubleValue ?? 0

        return FocusSignals(
            eyeOpenness: openness,
            yaw: yaw,
            pitch: pitch,
            eyesClosed: openness < eyesClosedThreshold,
            lookingAway: abs(yaw) > yawAwayThreshold || abs(pitch) > pitchAwayThreshold
        )
    }

    // MARK: - Eye openness

    /// Averages the openness of both eyes. Uses the bounding extent of each eye's
    /// landmark points (height / width) — robust to Vision's point ordering, unlike
    /// the classic 6-point EAR which assumes a fixed constellation order.
    private func eyeOpenness(_ landmarks: VNFaceLandmarks2D?) -> Double {
        guard let landmarks else { return 0.3 }
        let values = [landmarks.leftEye, landmarks.rightEye].compactMap(openness(of:))
        guard !values.isEmpty else { return 0.3 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func openness(of region: VNFaceLandmarkRegion2D?) -> Double? {
        guard let points = region?.normalizedPoints, points.count >= 4 else { return nil }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return nil }
        let width = maxX - minX
        guard width > 0 else { return nil }
        return Double((maxY - minY) / width)
    }
}
