//
//  PostureOverlayView.swift
//  StudyGuard
//

import SwiftUI

/// Draws the detected body skeleton over the (mirrored) camera preview.
///
/// Joints arrive in Vision-normalized coordinates (origin bottom-left, y up) from
/// the un-mirrored data output. The preview is mirrored, so x is mirrored here and
/// y is flipped to SwiftUI's top-left origin. Note: this uses a simple per-axis
/// scale and does not compensate for `resizeAspectFill` cropping, so alignment may
/// need a small tweak on-device.
struct PostureOverlayView: View {
    let joints: [String: CGPoint]
    var color: Color = Theme.orange

    var body: some View {
        GeometryReader { geo in
            let map: (CGPoint) -> CGPoint = { p in
                CGPoint(x: (1 - p.x) * geo.size.width,
                        y: (1 - p.y) * geo.size.height)
            }

            ZStack {
                Path { path in
                    for (a, b) in PostureSkeleton.bones {
                        if let pa = joints[a], let pb = joints[b] {
                            path.move(to: map(pa))
                            path.addLine(to: map(pb))
                        }
                    }
                }
                .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                ForEach(Array(joints.keys), id: \.self) { key in
                    if let p = joints[key] {
                        Circle()
                            .fill(.white)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(color, lineWidth: 2))
                            .position(map(p))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
