//
//  CameraPreviewView.swift
//  StudyGuard
//

import SwiftUI
import AVFoundation

/// SwiftUI wrapper around `AVCaptureVideoPreviewLayer`.
///
/// The preview is mirrored for a natural selfie view; this is independent of the
/// data output feeding Vision, which stays un-mirrored so posture geometry (and
/// TLR/TLL classification) is correct.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill

        if let connection = view.videoPreviewLayer.connection {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    /// A `UIView` backed directly by an `AVCaptureVideoPreviewLayer`.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // Safe: layerClass guarantees the backing layer's type.
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
