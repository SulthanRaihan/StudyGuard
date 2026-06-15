//
//  FocusScoreView.swift
//  StudyGuard
//

import SwiftUI

/// A compact circular gauge showing a 0–100 score with a colored ring.
/// Reused for both focus and posture readouts in the session overlay.
struct FocusScoreView: View {
    let title: String
    let score: Double
    let caption: String

    private var fraction: CGFloat { CGFloat(max(0, min(100, score)) / 100) }

    private var color: Color {
        switch score {
        case 80...: return .green
        case 50..<80: return .yellow
        default: return .orange
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.18), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: fraction)
                Text("\(Int(score))")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 72, height: 72)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct FocusScoreView_Previews: PreviewProvider {
    static var previews: some View {
        FocusScoreView(title: "Fokus", score: 82, caption: "Fokus")
            .padding()
            .background(.gray)
    }
}
