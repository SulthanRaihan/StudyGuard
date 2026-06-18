//
//  BreakChatView.swift
//  StudyGuard
//

import SwiftUI

/// Quick AI chat during a break (Groq). Camera stays off; study questions only.
struct BreakChatView: View {
    let subject: String

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [GroqService.Message] = []
    @State private var input = ""
    @State private var isSending = false
    @State private var errorText: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            if messages.isEmpty {
                                emptyState
                            }
                            ForEach(messages) { message in
                                bubble(for: message).id(message.id)
                            }
                            if isSending { typingIndicator }
                        }
                        .padding(16)
                    }
                    .onChange(of: messages.count) { _ in
                        guard let last = messages.last else { return }
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                    .onChange(of: isSending) { sending in
                        guard sending else { return }
                        withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                    }
                }

                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }

                inputBar
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { headerTitle }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.orange)
                }
            }
        }
    }

    // MARK: - Header

    private var headerTitle: some View {
        HStack(spacing: 8) {
            BrandImage(name: "GuriHi", fallbackSystemName: "sparkles")
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text("Ask Guri").font(.headline).foregroundStyle(Theme.navy)
                Text(subject).font(.caption2).foregroundStyle(Theme.muted)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            BrandImage(name: "GuriHi", fallbackSystemName: "bubble.left.and.bubble.right.fill")
                .frame(width: 96, height: 96)
            VStack(spacing: 4) {
                Text("Ask me anything about \(subject)")
                    .font(.headline)
                    .foregroundStyle(Theme.navy)
                    .multilineTextAlignment(.center)
                Text("I can explain concepts, solve problems, or quiz you during your break.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            suggestionChips
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }

    private var suggestionChips: some View {
        let suggestions = [
            "Explain a key concept in \(subject)",
            "Give me a quick practice question",
            "Summarize what I should review next"
        ]
        return VStack(spacing: 8) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    input = suggestion
                    inputFocused = true
                } label: {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundStyle(Theme.navy)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.navy.opacity(0.08)))
                }
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Bubbles

    @ViewBuilder
    private func bubble(for message: GroqService.Message) -> some View {
        let isUser = message.role == "user"
        HStack(alignment: .top, spacing: 8) {
            if isUser {
                Spacer(minLength: 36)
            } else {
                BrandImage(name: "GuriHi", fallbackSystemName: "sparkles")
                    .frame(width: 26, height: 26)
            }

            Text(message.content)
                .font(.callout)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(isUser ? AnyShapeStyle(Theme.orange) : AnyShapeStyle(Color.white),
                           in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(isUser ? .white : Theme.navy)
                .shadow(color: .black.opacity(isUser ? 0 : 0.04), radius: 4, y: 2)

            if !isUser { Spacer(minLength: 36) }
        }
    }

    private var typingIndicator: some View {
        HStack(alignment: .top, spacing: 8) {
            BrandImage(name: "GuriHi", fallbackSystemName: "sparkles")
                .frame(width: 26, height: 26)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Theme.muted)
                        .frame(width: 6, height: 6)
                        .opacity(isSending ? 1 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.15),
                            value: isSending
                        )
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
            Spacer(minLength: 36)
        }
        .id("typing")
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Type a question…", text: $input, axis: .vertical)
                .focused($inputFocused)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .lineLimit(1...4)
                .background(Color.white, in: Capsule())
                .overlay(Capsule().stroke(Theme.navy.opacity(0.08)))

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(canSend ? Theme.orange : Theme.muted.opacity(0.4), in: Circle())
            }
            .disabled(!canSend)
        }
        .padding(12)
        .background(Theme.cream)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespaces).isEmpty && !isSending
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        errorText = nil
        messages.append(GroqService.Message(role: "user", content: text))
        isSending = true
        do {
            let reply = try await GroqService.shared.breakChat(subject: subject, history: messages)
            messages.append(GroqService.Message(role: "assistant", content: reply))
        } catch {
            errorText = error.localizedDescription
        }
        isSending = false
    }
}

struct BreakChatView_Previews: PreviewProvider {
    static var previews: some View {
        BreakChatView(subject: "Mathematics")
    }
}
