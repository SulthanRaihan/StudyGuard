//
//  ScanView.swift
//  StudyGuard
//

import SwiftUI

/// Scan a problem with the camera (take a photo, on-device OCR), then solve it
/// with AI or turn it into flashcards. Manual text entry is always available.
struct ScanView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var recognizedText = ""
    @State private var answer: String?
    @State private var flashcards: [Flashcard] = []
    @State private var showAnswer = false
    @State private var showFlashcards = false
    @State private var showCamera = false
    @State private var isLoading = false
    @State private var isScanning = false
    @State private var errorText: String?

    private var canAct: Bool {
        !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    scanButton
                    editor
                    if let errorText {
                        Text(errorText).font(.caption).foregroundStyle(.red)
                    }
                    actions
                    Color.clear.frame(height: 8)
                }
                .padding(20)
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
            .sheet(isPresented: $showFlashcards) { FlashcardsView(cards: flashcards) }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPhotoPicker { image in
                    showCamera = false
                    Task { await scan(image) }
                }
                .ignoresSafeArea()
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 44)).foregroundStyle(Theme.orange)
            Text("Snap a photo of a problem and let Guri read & solve it.")
                .font(.subheadline).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var scanButton: some View {
        Button { showCamera = true } label: {
            if isScanning {
                ProgressView().tint(.white)
            } else {
                Label("Scan with Camera", systemImage: "camera.fill")
            }
        }
        .buttonStyle(.sgPrimary)
        .disabled(isScanning)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Problem text").font(.headline).foregroundStyle(Theme.navy)
            TextEditor(text: $recognizedText)
                .frame(height: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.navy.opacity(0.1)))
        }
    }

    private var actions: some View {
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

    private func scan(_ image: UIImage) async {
        isScanning = true; errorText = nil
        let text = await TextRecognizer.recognize(in: image)
        if text.isEmpty {
            errorText = "Couldn't read any text — try again with better lighting."
        } else {
            recognizedText = text
        }
        isScanning = false
    }

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
