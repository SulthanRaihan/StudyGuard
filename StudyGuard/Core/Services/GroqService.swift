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
        case http(Int, String)
        case empty

        var errorDescription: String? {
            switch self {
            case .missingKey: return "Groq API key not found in Secrets.plist."
            case .http(let code, let body):
                let detail = body.isEmpty ? "" : " — \(body.prefix(200))"
                return "Groq API error (HTTP \(code))\(detail)"
            case .empty: return "Groq returned no answer."
            }
        }
    }

    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let model = "llama-3.3-70b-versatile"

    // MARK: - Public use cases

    /// One-shot personal session summary (called once at session end).
    func sessionSummary(for result: SessionResult) async throws -> String {
        let issue = result.dominantIssue?.rawValue ?? "none"
        let prompt = """
        Analyze this study session and write a personal, conversational summary.

        Subject: \(result.subject)
        Duration: \(result.durationMinutes) minutes
        Posture score: \(Int(result.avgPosture))%
        Focus score: \(Int(result.avgFocus))%
        Dominant posture issue: \(issue)
        Alert count: \(result.postureAlertCount)

        Focus timeline (score per minute):
        \(result.focusTimelineString)

        Write a personal summary in English, max 150 words.
        Mention when focus dropped (if any) and give 2 concrete tips for the next session.
        """
        return try await complete(messages: [Message(role: "user", content: prompt)], maxTokens: 400)
    }

    /// Solves/answers a problem captured by OCR or typed by the user.
    func solveProblem(_ problem: String) async throws -> String {
        let prompt = """
        Solve or answer the following problem clearly and concisely, showing the key steps.
        If it's a math problem, show the working. Use English.

        Problem:
        \(problem)
        """
        return try await complete(messages: [Message(role: "user", content: prompt)], maxTokens: 700)
    }

    /// Generates flashcards (Q&A) from study material.
    func generateFlashcards(from text: String, count: Int = 6) async throws -> [Flashcard] {
        let prompt = """
        From the following study material, create \(count) flashcards for active recall.
        Respond ONLY with a JSON array of objects with keys "question" and "answer". No prose.

        Material:
        \(text)
        """
        let raw = try await complete(messages: [Message(role: "user", content: prompt)], maxTokens: 900)
        return Self.parseFlashcards(raw)
    }

    private static func parseFlashcards(_ text: String) -> [Flashcard] {
        struct DTO: Decodable { let question: String; let answer: String }
        guard let match = text.range(of: #"\[[\s\S]*\]"#, options: .regularExpression) else { return [] }
        let json = String(text[match])
        guard let data = json.data(using: .utf8),
              let dtos = try? JSONDecoder().decode([DTO].self, from: data) else { return [] }
        return dtos.map { Flashcard(question: $0.question, answer: $0.answer) }
    }

    /// Generates an adaptive multi-day study plan.
    func generateStudyPlan(subjects: [String], days: Int, hoursPerDay: Int,
                           bestFocusHour: Int?) async throws -> [StudyPlanDay] {
        let focusNote = bestFocusHour.map {
            "The student focuses best around \($0):00 — schedule the most demanding subjects around then."
        } ?? ""
        let prompt = """
        Create a \(days)-day study plan for these subjects: \(subjects.joined(separator: ", ")).
        Aim for about \(hoursPerDay) hour(s) per day, split into focused blocks.
        \(focusNote)
        Respond ONLY with a JSON array of \(days) objects, each:
        {"day":"Day 1","tasks":[{"subject":"Math","activity":"Review derivatives","minutes":30}]}
        No prose.
        """
        let raw = try await complete(messages: [Message(role: "user", content: prompt)], maxTokens: 1200)
        return Self.parsePlan(raw)
    }

    private static func parsePlan(_ text: String) -> [StudyPlanDay] {
        guard let match = text.range(of: #"\[[\s\S]*\]"#, options: .regularExpression) else { return [] }
        let json = String(text[match])
        guard let data = json.data(using: .utf8),
              let days = try? JSONDecoder().decode([StudyPlanDay].self, from: data) else { return [] }
        return days
    }

    /// A short narrative weekly report from the week's aggregated stats.
    func weeklyReport(sessions: Int, totalMinutes: Int, avgFocus: Int, avgPosture: Int,
                      bestFocusHour: Int?, weakestSubject: String?) async throws -> String {
        let focusNote = bestFocusHour.map { "Best focus time: around \($0):00." } ?? ""
        let weakNote = weakestSubject.map { "Weakest subject (lowest focus): \($0)." } ?? ""
        let prompt = """
        Write a short, encouraging weekly study report (max 120 words, English).

        Sessions this week: \(sessions)
        Total study time: \(totalMinutes) minutes
        Average focus: \(avgFocus)%
        Average posture: \(avgPosture)%
        \(focusNote)
        \(weakNote)

        Summarize the week and give 2 concrete suggestions for next week.
        """
        return try await complete(messages: [Message(role: "user", content: prompt)], maxTokens: 300)
    }

    /// Break chat: answers a study question, given the running conversation.
    func breakChat(subject: String, history: [Message]) async throws -> String {
        let system = Message(role: "system", content: """
        You are a study assistant helping a student understand their coursework.
        The user is on a break from studying \(subject).
        Answer briefly, clearly, and in plain language. Use English. Max 100 words per answer.
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
        guard let http = response as? HTTPURLResponse else { throw GroqError.http(-1, "") }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("⚠️ Groq HTTP \(http.statusCode): \(body)")
            throw GroqError.http(http.statusCode, body)
        }

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
