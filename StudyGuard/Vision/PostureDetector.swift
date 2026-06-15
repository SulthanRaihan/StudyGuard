//
//  PostureDetector.swift
//  StudyGuard
//

import Vision
import CoreML
import CoreVideo

/// The 24 derived posture features, in the exact order expected by
/// `PostureClassifier.mlmodel` (must match `posture_train.csv` columns).
///
/// Formulas mirror the reference Python feature-engineering script.
/// Vision's body-pose points use a bottom-left origin with y increasing
/// upward; MediaPipe (used to build the training CSV) uses a top-left
/// origin with y increasing downward. `PostureDetector` converts every
/// keypoint with `y' = 1 - y` before computing these features so the
/// formulas below can match the reference implementation verbatim.
struct PostureFeatures {
    var neckShoulderAngleLeft: Double
    var neckShoulderAngleRight: Double
    var earShoulderOffsetXLeft: Double
    var earShoulderOffsetYLeft: Double
    var earShoulderOffsetXRight: Double
    var earShoulderOffsetYRight: Double
    var shoulderLevelDiff: Double
    var headForwardOffset: Double
    var headVerticalOffset: Double
    var spineCurveUpper: Double
    var spineCurveLower: Double
    var shoulderHipOffsetX: Double
    var shoulderHipOffsetY: Double
    var hipLevelDiff: Double
    var elbowAngleLeft: Double
    var elbowAngleRight: Double
    var kneeAngleLeft: Double
    var kneeAngleRight: Double
    var hipAngleLeft: Double
    var hipAngleRight: Double
    var earLevelDiff: Double
    var wristShoulderOffsetYLeft: Double
    var wristShoulderOffsetYRight: Double
    var bodyLeanX: Double
}

/// Result of a single posture inference.
struct PostureResult {
    let type: PostureType
    let confidence: Double
    let features: PostureFeatures
}

/// Runs Vision body-pose detection on a camera frame, derives the 24
/// posture features, and classifies them with `PostureClassifier.mlmodel`.
final class PostureDetector {

    /// Minimum per-joint confidence required to trust a keypoint.
    private let minJointConfidence: Float = 0.3

    private let model: PostureClassifier

    init() throws {
        model = try PostureClassifier(configuration: MLModelConfiguration())
    }

    /// Runs body-pose detection + posture classification on a frame.
    /// Returns `nil` if no body (or not enough confident joints) is detected.
    func detectPosture(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> PostureResult? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else { return nil }
        guard let keypoints = try extractKeypoints(from: observation) else { return nil }

        let features = computeFeatures(keypoints)
        return try classify(features)
    }

    // MARK: - Keypoint extraction

    private struct Keypoints {
        var nose: CGPoint
        var leftEar: CGPoint
        var rightEar: CGPoint
        var leftShoulder: CGPoint
        var rightShoulder: CGPoint
        var leftElbow: CGPoint
        var rightElbow: CGPoint
        var leftWrist: CGPoint
        var rightWrist: CGPoint
        var leftHip: CGPoint
        var rightHip: CGPoint
        var leftKnee: CGPoint
        var rightKnee: CGPoint
        var leftAnkle: CGPoint
        var rightAnkle: CGPoint
    }

    /// Reads the 15 required joints, requiring each to clear
    /// `minJointConfidence`, and flips `y` to match the MediaPipe
    /// (top-left origin, y-down) convention used by the training data.
    private func extractKeypoints(from observation: VNHumanBodyPoseObservation) throws -> Keypoints? {
        let joints: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .leftEar, .rightEar,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]

        let recognized = try observation.recognizedPoints(.all)

        var points: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for joint in joints {
            guard let point = recognized[joint], point.confidence >= minJointConfidence else {
                return nil
            }
            // Vision: origin bottom-left, y up -> MediaPipe: origin top-left, y down
            points[joint] = CGPoint(x: point.location.x, y: 1.0 - point.location.y)
        }

        return Keypoints(
            nose: points[.nose]!,
            leftEar: points[.leftEar]!,
            rightEar: points[.rightEar]!,
            leftShoulder: points[.leftShoulder]!,
            rightShoulder: points[.rightShoulder]!,
            leftElbow: points[.leftElbow]!,
            rightElbow: points[.rightElbow]!,
            leftWrist: points[.leftWrist]!,
            rightWrist: points[.rightWrist]!,
            leftHip: points[.leftHip]!,
            rightHip: points[.rightHip]!,
            leftKnee: points[.leftKnee]!,
            rightKnee: points[.rightKnee]!,
            leftAnkle: points[.leftAnkle]!,
            rightAnkle: points[.rightAnkle]!
        )
    }

    // MARK: - Feature computation

    private func computeFeatures(_ k: Keypoints) -> PostureFeatures {
        let midShoulder = midpoint(k.leftShoulder, k.rightShoulder)
        let midHip = midpoint(k.leftHip, k.rightHip)
        let midEar = midpoint(k.leftEar, k.rightEar)
        let midKnee = midpoint(k.leftKnee, k.rightKnee)
        let midAnkle = midpoint(k.leftAnkle, k.rightAnkle)

        return PostureFeatures(
            neckShoulderAngleLeft: angleBetween(k.leftEar, k.leftShoulder, k.leftHip),
            neckShoulderAngleRight: angleBetween(k.rightEar, k.rightShoulder, k.rightHip),

            earShoulderOffsetXLeft: offsetX(k.leftEar, k.leftShoulder),
            earShoulderOffsetYLeft: offsetY(k.leftEar, k.leftShoulder),
            earShoulderOffsetXRight: offsetX(k.rightEar, k.rightShoulder),
            earShoulderOffsetYRight: offsetY(k.rightEar, k.rightShoulder),

            shoulderLevelDiff: k.leftShoulder.y - k.rightShoulder.y,

            headForwardOffset: offsetX(k.nose, midShoulder),
            headVerticalOffset: offsetY(k.nose, midShoulder),

            spineCurveUpper: angleBetween(midEar, midShoulder, midHip),
            spineCurveLower: angleBetween(midShoulder, midHip, midKnee),

            shoulderHipOffsetX: offsetX(midShoulder, midHip),
            shoulderHipOffsetY: offsetY(midShoulder, midHip),

            hipLevelDiff: k.leftHip.y - k.rightHip.y,

            elbowAngleLeft: angleBetween(k.leftShoulder, k.leftElbow, k.leftWrist),
            elbowAngleRight: angleBetween(k.rightShoulder, k.rightElbow, k.rightWrist),

            kneeAngleLeft: angleBetween(k.leftHip, k.leftKnee, k.leftAnkle),
            kneeAngleRight: angleBetween(k.rightHip, k.rightKnee, k.rightAnkle),

            hipAngleLeft: angleBetween(k.leftShoulder, k.leftHip, k.leftKnee),
            hipAngleRight: angleBetween(k.rightShoulder, k.rightHip, k.rightKnee),

            earLevelDiff: k.leftEar.y - k.rightEar.y,

            wristShoulderOffsetYLeft: offsetY(k.leftWrist, k.leftShoulder),
            wristShoulderOffsetYRight: offsetY(k.rightWrist, k.rightShoulder),

            bodyLeanX: offsetX(midShoulder, midAnkle)
        )
    }

    // MARK: - Geometry helpers (mirror extract_features.py)

    /// Angle at vertex `b`, formed by `a-b-c`, in degrees (0-180).
    private func angleBetween(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
        let ba = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let bc = CGVector(dx: c.x - b.x, dy: c.y - b.y)

        let normBA = (ba.dx * ba.dx + ba.dy * ba.dy).squareRoot()
        let normBC = (bc.dx * bc.dx + bc.dy * bc.dy).squareRoot()

        guard normBA > 0, normBC > 0 else { return 0.0 }

        var cosine = (ba.dx * bc.dx + ba.dy * bc.dy) / (normBA * normBC)
        cosine = min(1.0, max(-1.0, cosine))

        return acos(cosine) * 180.0 / Double.pi
    }

    private func offsetX(_ p1: CGPoint, _ p2: CGPoint) -> Double { p1.x - p2.x }
    private func offsetY(_ p1: CGPoint, _ p2: CGPoint) -> Double { p1.y - p2.y }

    private func midpoint(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        CGPoint(x: (p1.x + p2.x) / 2.0, y: (p1.y + p2.y) / 2.0)
    }

    // MARK: - Classification

    private func classify(_ f: PostureFeatures) throws -> PostureResult {
        let output = try model.prediction(
            neck_shoulder_angle_left: f.neckShoulderAngleLeft,
            neck_shoulder_angle_right: f.neckShoulderAngleRight,
            ear_shoulder_offset_x_left: f.earShoulderOffsetXLeft,
            ear_shoulder_offset_y_left: f.earShoulderOffsetYLeft,
            ear_shoulder_offset_x_right: f.earShoulderOffsetXRight,
            ear_shoulder_offset_y_right: f.earShoulderOffsetYRight,
            shoulder_level_diff: f.shoulderLevelDiff,
            head_forward_offset: f.headForwardOffset,
            head_vertical_offset: f.headVerticalOffset,
            spine_curve_upper: f.spineCurveUpper,
            spine_curve_lower: f.spineCurveLower,
            shoulder_hip_offset_x: f.shoulderHipOffsetX,
            shoulder_hip_offset_y: f.shoulderHipOffsetY,
            hip_level_diff: f.hipLevelDiff,
            elbow_angle_left: f.elbowAngleLeft,
            elbow_angle_right: f.elbowAngleRight,
            knee_angle_left: f.kneeAngleLeft,
            knee_angle_right: f.kneeAngleRight,
            hip_angle_left: f.hipAngleLeft,
            hip_angle_right: f.hipAngleRight,
            ear_level_diff: f.earLevelDiff,
            wrist_shoulder_offset_y_left: f.wristShoulderOffsetYLeft,
            wrist_shoulder_offset_y_right: f.wristShoulderOffsetYRight,
            body_lean_x: f.bodyLeanX
        )

        let label = output.posture_label
        let type = PostureType(rawValue: label) ?? .tup
        let confidence = output.posture_labelProbability[label] ?? 0.0

        return PostureResult(type: type, confidence: confidence, features: f)
    }
}
