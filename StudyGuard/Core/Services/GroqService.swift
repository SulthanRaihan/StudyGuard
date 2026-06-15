//
//  GroqService.swift
//  StudyGuard
//

import Foundation

/// Calls the Groq chat-completions API (llama3-70b) for the session summary and
/// the break chat. The API key is read from the gitignored `Secrets.plist`.
final class GroqService {

    static let shared = GroqService()
    private init() {}

    struct Message: Codable, Identifiable, Equatable {
        var id = UUID()
        let role: String        // "system" | "user" | "assistant"
        let content: String

        private enum CodingKeys: String, CodingKey { case role, content }
    }

    enum GroqError: LocalizedError {
        case missingKey
        case http(Int)
        case empty

        var errorDescription: String? {
            switch self {
            case .missingKey: return "Groq API key tidak ditemukan di Secrets.plist."
            case .http(let code): return "Groq API error (HTTP \(code))."
            case .empty: return "Groq tidak mengembalikan jawaban."
            }
        }
    }

    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let model = "llama3-70b-8192"

    // MARK: - Public use cases

    /// One-shot personal session summary (called once at session end).
    func sessionSummary(for result: SessionResult) async throws -> String {
        let issue = result.dominantIssue?.rawValue ?? "tidak ada"
        let prompt = """
        Analisis sesi belajar ini dan buat summary yang personal dan conversational.

        Subject: \(result.subject)
        Durasi: \(result.durationMinutes) menit
        Posture score: \(Int(result.avgPosture))%
        Focus score: \(Int(result.avgFocus))%
        Dominant posture issue: \(issue)
        Alert count: \(result.postureAlertCount) kali

        Focus timeline (skor per menit):
        \(result.focusTimelineString)

        Buat summary personal maksimal 150 kata dalam bahasa Indonesia.
        Sebutkan kapan fokus drop (jika ada) dan berikan 2 saran konkret untuk sesi berikutnya.
        """
        return try await complete(messages: [Message(role: "user", content: prompt)], maxTokens: 400)
    }

    /// Break chat: answers a study question, given the running conversation.
    func breakChat(subject: String, history: [Message]) async throws -> String {
        let system = Message(role: "system", content: """
        Kamu adalah asisten belajar yang membantu mahasiswa memahami materi kuliah.
        User sedang break dari sesi belajar \(subject).
        Jawab pertanyaan dengan singkat, jelas, dan mudah dipahami.
        Gunakan bahasa Indonesia. Maksimal 100 kata per jawaban.
        """)
        return try await complete(messages: [system] + history, maxTokens: 300)
    }

    // MARK: - Networking

    private func complete(messages: [Message], maxTokens: Int) async throws -> String {
        guard let key = apiKey, !key.isEmpty else { throw GroqError.missingKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            RequestBody(model: model, messages: messages, max_tokens: maxTokens, temperature: 0.7)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GroqError.http(-1) }
        guard (200..<300).contains(http.statusCode) else { throw GroqError.http(http.statusCode) }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw GroqError.empty
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Wire types

    private struct RequestBody: Encodable {
        let model: String
        let messages: [Message]
        let max_tokens: Int
        let temperature: Double
    }

    private struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct Msg: Decodable { let content: String }
            let message: Msg
        }
        let choices: [Choice]
    }

    // MARK: - Secrets

    private var apiKey: String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any] else { return nil }
        return dict["GroqAPIKey"] as? String
    }
}
