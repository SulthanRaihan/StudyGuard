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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if messages.isEmpty {
                                Text("Tanya apa saja tentang \(subject) selama istirahat. 🤓")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 40)
                            }
                            ForEach(messages) { message in
                                bubble(for: message).id(message.id)
                            }
                            if isSending {
                                ProgressView().padding(.leading, 8)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }

                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                inputBar
            }
            .navigationTitle("Tanya AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func bubble(for message: GroqService.Message) -> some View {
        let isUser = message.role == "user"
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(message.content)
                .padding(12)
                .background(isUser ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.thinMaterial),
                           in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(isUser ? .white : .primary)
            if !isUser { Spacer(minLength: 40) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Tulis pertanyaan…", text: $input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
            }
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
        .padding()
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
        BreakChatView(subject: "Matematika")
    }
}
