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
    /// Confident joints for the on-screen skeleton, in Vision-normalized coords
    /// (origin bottom-left, y up). Keyed by joint name.
    var joints: [String: CGPoint] = [:]
}

/// Bones to draw for the skeleton overlay (pairs of joint-name keys).
enum PostureSkeleton {
    static let bones: [(String, String)] = [
        ("leftEar", "leftShoulder"), ("rightEar", "rightShoulder"),
        ("nose", "neck"), ("neck", "leftShoulder"), ("neck", "rightShoulder"),
        ("leftShoulder", "rightShoulder"),
        ("leftShoulder", "leftElbow"), ("leftElbow", "leftWrist"),
        ("rightShoulder", "rightElbow"), ("rightElbow", "rightWrist"),
        ("neck", "root"), ("root", "leftHip"), ("root", "rightHip"),
        ("leftShoulder", "leftHip"), ("rightShoulder", "rightHip")
    ]
}

/// Runs Vision body-pose detection on a camera frame, derives the 24
/// posture features, and classifies them with `PostureClassifier.mlmodel`.
final class PostureDetector {

    /// Minimum per-joint confidence to accept a Vision keypoint for ML classification.
    /// Kept low because Vision reports occluded-but-inferred joints with low
    /// confidence, and we want to use those (the training pipeline likewise relied
    /// on estimated keypoints).
    private let minJointConfidence: Float = 0.1

    /// Minimum confidence for a joint to be drawn in the on-screen skeleton overlay.
    /// Much stricter than `minJointConfidence` — a desk setup often occludes hips/
    /// elbows/wrists, and at low confidence Vision's *guessed* position for those
    /// joints jumps around messily. Only draw joints Vision can actually see well.
    private let minDisplayConfidence: Float = 0.45

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
        var result = try classify(features)
        result.joints = displayJoints(from: observation)
        return result
    }

    /// Confident joints (original Vision coords, y up) for the skeleton overlay.
    private func displayJoints(from observation: VNHumanBodyPoseObservation) -> [String: CGPoint] {
        let map: [(VNHumanBodyPoseObservation.JointName, String)] = [
            (.nose, "nose"), (.neck, "neck"), (.root, "root"),
            (.leftEar, "leftEar"), (.rightEar, "rightEar"),
            (.leftShoulder, "leftShoulder"), (.rightShoulder, "rightShoulder"),
            (.leftElbow, "leftElbow"), (.rightElbow, "rightElbow"),
            (.leftWrist, "leftWrist"), (.rightWrist, "rightWrist"),
            (.leftHip, "leftHip"), (.rightHip, "rightHip")
        ]
        guard let recognized = try? observation.recognizedPoints(.all) else { return [:] }
        var out: [String: CGPoint] = [:]
        for (joint, key) in map {
            if let point = recognized[joint], point.confidence >= minDisplayConfidence {
                out[key] = point.location
            }
        }
        return out
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

    /// Builds the 15-joint skeleton, flipping `y` to the training convention
    /// (top-left origin, y-down).
    ///
    /// A desk webcam only reliably sees the upper body, so only the upper-body
    /// joints are required; occluded lower-body joints are estimated from the
    /// torso. This mirrors the training pipeline (MediaPipe always emits a full
    /// skeleton) and keeps the 24-feature vector complete. Returns `nil` only
    /// when the upper body itself isn't confidently visible.
    private func extractKeypoints(from observation: VNHumanBodyPoseObservation) throws -> Keypoints? {
        let recognized = try observation.recognizedPoints(.all)

        // Vision: origin bottom-left, y up -> training: origin top-left, y down.
        func point(_ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let p = recognized[joint], p.confidence >= minJointConfidence else { return nil }
            return CGPoint(x: p.location.x, y: 1.0 - p.location.y)
        }

        // Required: the upper body that drives the reliable TUP/TLF/TLR/TLL geometry.
        guard let nose = point(.nose),
              let leftEar = point(.leftEar),
              let rightEar = point(.rightEar),
              let leftShoulder = point(.leftShoulder),
              let rightShoulder = point(.rightShoulder)
        else { return nil }

        // Estimate any joint Vision can't see, walking down the body from the torso.
        let span = max(0.05, hypot(leftShoulder.x - rightShoulder.x,
                                   leftShoulder.y - rightShoulder.y))
        func below(_ p: CGPoint, _ factor: CGFloat) -> CGPoint {
            CGPoint(x: p.x, y: p.y + span * factor)
        }

        let leftElbow  = point(.leftElbow)  ?? below(leftShoulder, 1.0)
        let rightElbow = point(.rightElbow) ?? below(rightShoulder, 1.0)
        let leftWrist  = point(.leftWrist)  ?? below(leftElbow, 1.0)
        let rightWrist = point(.rightWrist) ?? below(rightElbow, 1.0)
        let leftHip    = point(.leftHip)    ?? below(leftShoulder, 1.6)
        let rightHip   = point(.rightHip)   ?? below(rightShoulder, 1.6)
        let leftKnee   = point(.leftKnee)   ?? below(leftHip, 1.8)
        let rightKnee  = point(.rightKnee)  ?? below(rightHip, 1.8)
        let leftAnkle  = point(.leftAnkle)  ?? below(leftKnee, 1.8)
        let rightAnkle = point(.rightAnkle) ?? below(rightKnee, 1.8)

        return Keypoints(
            nose: nose,
            leftEar: leftEar,
            rightEar: rightEar,
            leftShoulder: leftShoulder,
            rightShoulder: rightShoulder,
            leftElbow: leftElbow,
            rightElbow: rightElbow,
            leftWrist: leftWrist,
            rightWrist: rightWrist,
            leftHip: leftHip,
            rightHip: rightHip,
            leftKnee: leftKnee,
            rightKnee: rightKnee,
            leftAnkle: leftAnkle,
            rightAnkle: rightAnkle
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
