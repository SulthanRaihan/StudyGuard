//
//  AnimatedGIFView.swift
//  StudyGuard
//

import SwiftUI
import UIKit
import ImageIO

/// Plays an animated GIF from a URL. SwiftUI's `AsyncImage` only shows a GIF's
/// first (static) frame, so this decodes all frames with ImageIO and animates
/// them in a `UIImageView`. No third-party dependency.
struct AnimatedGIFView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        context.coordinator.load(url, into: imageView)
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var task: URLSessionDataTask?

        func load(_ url: URL, into imageView: UIImageView) {
            task?.cancel()
            task = URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data, let image = UIImage.animatedGIF(data: data) else { return }
                DispatchQueue.main.async { imageView.image = image }
            }
            task?.resume()
        }

        deinit { task?.cancel() }
    }
}

private extension UIImage {
    /// Builds an animated `UIImage` from GIF data, honoring per-frame delays.
    static func animatedGIF(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        var frames: [UIImage] = []
        var totalDuration: Double = 0

        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))
            totalDuration += frameDelay(source: source, index: index)
        }

        guard frames.count > 1 else { return frames.first }
        return UIImage.animatedImage(with: frames, duration: totalDuration)
    }

    static func frameDelay(source: CGImageSource, index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }
        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double
        let delay = unclamped ?? clamped ?? 0.1
        return delay < 0.02 ? 0.1 : delay   // browsers clamp very short delays
    }
}
