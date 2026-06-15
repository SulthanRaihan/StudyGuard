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

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.headline)
                if let instructions = exercise.instructions {
                    Text(instructions)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("\(exercise.duration) detik")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tint)
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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .opacity(isDone ? 0.6 : 1)
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
