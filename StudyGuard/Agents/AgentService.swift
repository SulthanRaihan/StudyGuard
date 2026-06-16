//
//  AgentService.swift
//  StudyGuard
//
//  HTTP client for the CrewAI agents backend. Optional: only active when an
//  `AgentBackendURL` is set in Secrets.plist. Returns nil on any failure so the
//  app is unaffected when the backend is down or unconfigured.
//

import Foundation

final class AgentService {

    static let shared = AgentService()
    private init() {}

    /// Whether a backend URL is configured (drives whether the UI even tries).
    var isConfigured: Bool { baseURL != nil }

    /// Runs the agents over a finished session. Returns nil if unconfigured/unreachable.
    func analyze(_ result: SessionResult) async -> AgentAnalysis? {
        guard let baseURL else { return nil }
        guard let url = URL(string: "\(baseURL)/analyze-session") else { return nil }

        let payload = AgentSessionPayload(
            subject: result.subject,
            durationMinutes: result.durationMinutes,
            postureScore: result.avgPosture,
            focusScore: result.avgFocus,
            dominantIssue: result.dominantIssue?.rawValue,
            postureAlertCount: result.postureAlertCount,
            distractionCount: result.distractionCount,
            focusTimeline: result.focusTimeline,
            breakMinutes: result.breakMinutes
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let body = try? encoder.encode(payload) else { return nil }
        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(AgentAnalysis.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Config

    private var baseURL: String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let value = dict["AgentBackendURL"] as? String,
              !value.isEmpty else { return nil }
        return value.hasSuffix("/") ? String(value.dropLast()) : value
    }
}
