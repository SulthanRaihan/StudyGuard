//
//  FlashcardsView.swift
//  StudyGuard
//

import SwiftUI

/// Swipe through AI-generated flashcards; tap to flip between question and answer.
struct FlashcardsView: View {
    let cards: [Flashcard]

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var showAnswer = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if cards.isEmpty {
                    Text("No flashcards.").foregroundStyle(Theme.muted)
                } else {
                    Text("\(index + 1) of \(cards.count)")
                        .font(.subheadline).foregroundStyle(Theme.muted)

                    card

                    HStack(spacing: 16) {
                        Button { step(-1) } label: {
                            Image(systemName: "chevron.left").font(.title2)
                        }
                        .disabled(index == 0)

                        Button {
                            withAnimation { showAnswer.toggle() }
                        } label: {
                            Text(showAnswer ? "Show question" : "Show answer")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.sgSecondary)

                        Button { step(1) } label: {
                            Image(systemName: "chevron.right").font(.title2)
                        }
                        .disabled(index >= cards.count - 1)
                    }
                    .tint(Theme.orange)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("Flashcards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var card: some View {
        VStack(spacing: 14) {
            Text(showAnswer ? "ANSWER" : "QUESTION")
                .font(.caption.weight(.bold)).foregroundStyle(showAnswer ? Theme.green : Theme.orange)
            Text(showAnswer ? cards[index].answer : cards[index].question)
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.navy)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 220)
        }
        .padding(24)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: Theme.navy.opacity(0.08), radius: 12, y: 6)
        .onTapGesture { withAnimation { showAnswer.toggle() } }
    }

    private func step(_ delta: Int) {
        let next = index + delta
        guard cards.indices.contains(next) else { return }
        withAnimation {
            index = next
            showAnswer = false
        }
    }
}
