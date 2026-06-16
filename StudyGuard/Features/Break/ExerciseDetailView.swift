//
//  ExerciseDetailView.swift
//  StudyGuard
//

import SwiftUI

/// Full detail for one exercise: a large animated GIF demo + instructions.
struct ExerciseDetailView: View {
    let exercise: BreakExercise
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    gif

                    HStack(spacing: 10) {
                        badge(exercise.targetArea.label, "target")
                        badge("\(exercise.duration)s", "clock.fill")
                    }

                    if let instructions = exercise.instructions, !instructions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How to do it").font(.headline).foregroundStyle(Theme.navy)
                            Text(instructions)
                                .font(.callout).foregroundStyle(Theme.navy)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sgCard()
                    }
                }
                .padding(20)
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var gif: some View {
        if let gif = exercise.gifUrl, let url = URL(string: gif) {
            AnimatedGIFView(url: url)
                .frame(height: 280)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        } else {
            Image(systemName: "figure.cooldown")
                .font(.system(size: 80))
                .foregroundStyle(Theme.orange)
                .frame(height: 280)
                .frame(maxWidth: .infinity)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func badge(_ text: String, _ icon: String) -> some View {
        Label(text.capitalized, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.navy)
            .padding(.vertical, 8).padding(.horizontal, 14)
            .background(Theme.orange.opacity(0.15), in: Capsule())
    }
}

private extension TargetArea {
    var label: String {
        switch self {
        case .neck: return "neck"
        case .back: return "back"
        case .eyes: return "eyes"
        case .fullBody: return "full body"
        }
    }
}
