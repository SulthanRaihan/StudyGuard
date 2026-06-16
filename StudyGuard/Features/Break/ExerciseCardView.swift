//
//  ExerciseCardView.swift
//  StudyGuard
//

import SwiftUI

/// A single break-exercise card with a tap-to-complete control.
struct ExerciseCardView: View {
    let exercise: BreakExercise
    let isDone: Bool
    let onToggle: () -> Void
    var onTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.headline)
                if let instructions = exercise.instructions {
                    Text(instructions)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Label("\(exercise.duration)s · tap for demo", systemImage: "play.circle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.orange)
            }

            Spacer()

            Button(action: onToggle) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Theme.navy.opacity(0.05), radius: 6, y: 3)
        .opacity(isDone ? 0.6 : 1)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let gif = exercise.gifUrl, let url = URL(string: gif) {
            AnimatedGIFView(url: url)
                .frame(width: 64, height: 64)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Theme.orange)
                .frame(width: 64, height: 64)
        }
    }

    private var icon: String {
        switch exercise.targetArea {
        case .neck: return "figure.flexibility"
        case .back: return "figure.strengthtraining.traditional"
        case .eyes: return "eye"
        case .fullBody: return "figure.cooldown"
        }
    }
}

struct ExerciseCardView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseCardView(
            exercise: BreakExercise(id: "1", name: "Putar leher perlahan", duration: 20,
                                    targetArea: .neck, instructions: "Putar kepala perlahan."),
            isDone: false, onToggle: {}
        )
        .padding()
    }
}
