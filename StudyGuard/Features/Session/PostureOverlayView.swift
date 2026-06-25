//
//  PostureOverlayView.swift
//  StudyGuard
//

import SwiftUI

/// Draws the detected body skeleton over the (mirrored) camera preview.
///
/// Joints arrive in Vision-normalized coordinates (origin bottom-left, y up) from
/// the un-mirrored data output. The preview is mirrored and uses `resizeAspectFill`,
/// so we mirror x, flip y, and compensate for the aspect-fill crop assuming a 9:16
/// portrait camera buffer.
struct PostureOverlayView: View {
    let joints: [String: CGPoint]
    var color: Color = Theme.orange

    /// Camera buffer aspect (width / height), portrait.
    private let imageAspect: CGFloat = 9.0 / 16.0

    var body: some View {
        GeometryReader { geo in
            let map = mapper(for: geo.size)
            ZStack {
                Path { path in
                    for (a, b) in PostureSkeleton.bones {
                        if let pa = joints[a], let pb = joints[b] {
                            path.move(to: map(pa))
                            path.addLine(to: map(pb))
                        }
                    }
                }
                .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                ForEach(Array(joints.keys), id: \.self) { key in
                    if let p = joints[key] {
                        Circle()
                            .fill(.white)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(color, lineWidth: 2))
                            .position(map(p))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Maps a Vision-normalized point to view coordinates, accounting for mirror,
    /// y-flip, and resizeAspectFill cropping.
    private func mapper(for size: CGSize) -> (CGPoint) -> CGPoint {
        let viewAspect = size.width / size.height
        var scaleX = size.width, scaleY = size.height
        var offX: CGFloat = 0, offY: CGFloat = 0

        if viewAspect > imageAspect {
            // Image fills width; taller than the view -> cropped top/bottom.
            let displayedHeight = size.width / imageAspect
            scaleX = size.width
            scaleY = displayedHeight
            offY = (size.height - displayedHeight) / 2
        } else {
            // Image fills height; wider than the view -> cropped left/right.
            let displayedWidth = size.height * imageAspect
            scaleY = size.height
            scaleX = displayedWidth
            offX = (size.width - displayedWidth) / 2
        }

        return { p in
            CGPoint(x: offX + (1 - p.x) * scaleX,
                    y: offY + (1 - p.y) * scaleY)
        }
    }
}
