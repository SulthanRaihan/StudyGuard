//
//  ScanView.swift
//  StudyGuard
//

import SwiftUI

/// Scan a problem with the camera (on-device OCR), then solve it with AI or turn
/// it into flashcards. Falls back to manual text entry where live scanning isn't
/// available (e.g. Simulator).
struct ScanView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var recognizedText = ""
    @State private var answer: String?
    @State private var flashcards: [Flashcard] = []
    @State private var showAnswer = false
    @State private var showFlashcards = false
    @State private var isLoading = false
    @State private var errorText: String?

    private var canAct: Bool {
        !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scannerArea
                panel
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("Scan & Solve")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showAnswer) { answerSheet }
            .sheet(isPresented: $showFlashcards) {
                FlashcardsView(cards: flashcards)
            }
        }
    }

    // MARK: - Scanner

    @ViewBuilder
    private var scannerArea: some View {
        if DataScannerView.isSupported {
            ZStack(alignment: .top) {
                DataScannerView(recognizedText: $recognizedText)
                Text("Point at a problem — text is read on-device")
                    .font(.caption).foregroundStyle(.white)
                    .padding(8).background(.black.opacity(0.5), in: Capsule())
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 360)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "text.viewfinder").font(.system(size: 44)).foregroundStyle(Theme.orange)
                Text("Live scan isn't available here — type or paste your problem below.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }

    // MARK: - Panel

    private var panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Problem text").font(.headline).foregroundStyle(Theme.navy)

            TextEditor(text: $recognizedText)
                .frame(height: 90)
                .padding(8)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.navy.opacity(0.1)))

            if let errorText {
                Text(errorText).font(.caption).foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button { Task { await solve() } } label: {
                    if isLoading { ProgressView().tint(.white) }
                    else { Label("Solve with AI", systemImage: "sparkles") }
                }
                .buttonStyle(.sgPrimary)
                .disabled(!canAct)

                Button { Task { await makeFlashcards() } } label: {
                    Label("Flashcards", systemImage: "rectangle.on.rectangle")
                }
                .buttonStyle(.sgSecondary)
                .disabled(!canAct)
            }
        }
        .padding(20)
        .background(Theme.cream)
    }

    private var answerSheet: some View {
        NavigationStack {
            ScrollView {
                Text(answer ?? "")
                    .font(.callout).foregroundStyle(Theme.navy)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("AI Answer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showAnswer = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func solve() async {
        errorText = nil; isLoading = true
        do {
            answer = try await GroqService.shared.solveProblem(recognizedText)
            showAnswer = true
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }

    private func makeFlashcards() async {
        errorText = nil; isLoading = true
        do {
            let cards = try await GroqService.shared.generateFlashcards(from: recognizedText)
            if cards.isEmpty {
                errorText = "Couldn't generate flashcards from that text."
            } else {
                flashcards = cards
                showFlashcards = true
            }
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }
}
