//
//  CameraManager.swift
//  StudyGuard
//

import AVFoundation
import Combine

/// Owns the front-camera capture session and publishes each frame for
/// Vision processing (posture + focus detection).
///
/// The session is suspended during breaks via `pause()` / `resume()`.
final class CameraManager: NSObject, ObservableObject {

    enum AuthorizationState {
        case notDetermined
        case authorized
        case denied
    }

    @Published var authorizationState: AuthorizationState = .notDetermined
    @Published var isRunning = false

    /// Emits each captured frame on a background queue.
    let framePublisher = PassthroughSubject<CMSampleBuffer, Never>()

    let session = AVCaptureSession()

    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.studyguard.camera.session")
    private let videoQueue = DispatchQueue(label: "com.studyguard.camera.video")

    override init() {
        super.init()
        checkAuthorization()
    }

    // MARK: - Authorization

    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationState = .authorized
        case .notDetermined:
            authorizationState = .notDetermined
        default:
            authorizationState = .denied
        }
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                let newState: AuthorizationState = granted ? .authorized : .denied
                if self?.authorizationState != newState {
                    self?.authorizationState = newState
                }
                completion(granted)
            }
        }
    }

    // MARK: - Session lifecycle

    /// Configures and starts the capture session. Safe to call once;
    /// subsequent starts after `pause()` should use `resume()`.
    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.inputs.isEmpty {
                self.configureSession()
            }
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    if !self.isRunning { self.isRunning = true }
                }
            }
        }
    }

    /// Suspends the session, e.g. when entering BreakView.
    func pause() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    if self.isRunning { self.isRunning = false }
                }
            }
        }
    }

    /// Resumes a previously paused session, e.g. when a break ends.
    func resume() {
        start()
    }

    func stop() {
        pause()
    }

    // MARK: - Configuration

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if let connection = videoOutput.connection(with: .video) {
            // Feed Vision the TRUE geometry (un-mirrored): mirroring the data would
            // swap anatomical left/right and flip TLR/TLL classifications. The selfie
            // mirror is applied to the preview layer only (see CameraPreviewView).
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }

        configureFrameRate(for: device, fps: 30)

        session.commitConfiguration()
    }

    private func configureFrameRate(for device: AVCaptureDevice, fps: Double) {
        do {
            try device.lockForConfiguration()
            let duration = CMTime(value: 1, timescale: CMTimeScale(fps))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            device.unlockForConfiguration()
        } catch {
            // Frame rate is a best-effort optimization; fall back to device default.
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        framePublisher.send(sampleBuffer)
    }
}
