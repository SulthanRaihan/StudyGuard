//
//  ExerciseAPIService.swift
//  StudyGuard
//

import Foundation

/// Supplies break exercises matched to the session's dominant posture issue.
///
/// Primary source is the ExerciseDB API (RapidAPI), which returns animated GIF
/// demos. If the network/key is unavailable it falls back to a curated local set,
/// so a break always has something to show. An eye-rest (20-20-20) is always added.
final class ExerciseAPIService {

    static let shared = ExerciseAPIService()
    private init() {}

    private let host = "exercisedb.p.rapidapi.com"

    /// Returns a break routine: stretches matched to the posture issue + a couple of
    /// energizing body-weight moves (push-ups etc.) + an eye rest.
    func routine(for issue: PostureType?, breakMinutes: Int) async -> [BreakExercise] {
        var exercises: [BreakExercise] = []

        if let key = apiKey, !key.isEmpty {
            if let stretches = try? await fetchExercises(bodyPart: bodyPart(for: issue), key: key) {
                exercises += Array(stretches.prefix(4))   // posture stretches
            }
            if let energize = try? await fetchExercises(bodyPart: "chest", key: key) {
                exercises += Array(energize.prefix(2))     // push-up-style energizers
            }
        }

        if exercises.isEmpty {
            exercises = localExercises(for: issue)
        }

        exercises.append(eyeRest)
        return exercises
    }

    // MARK: - ExerciseDB API

    private func fetchExercises(bodyPart: String, key: String) async throws -> [BreakExercise] {
        let encoded = bodyPart.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bodyPart
        guard let url = URL(string: "https://\(host)/exercises/bodyPart/\(encoded)?limit=6") else { return [] }

        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue(host, forHTTPHeaderField: "X-RapidAPI-Host")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return []
        }

        let decoded = try JSONDecoder().decode([APIExercise].self, from: data)
        // Prefer body-weight moves (no equipment) for a desk break.
        let preferred = decoded.filter { $0.equipment.lowercased() == "body weight" }
        let chosen = preferred.isEmpty ? decoded : preferred

        return chosen.map { api in
            BreakExercise(
                id: api.id,
                name: api.name.capitalized,
                duration: 30,
                targetArea: targetArea(forBodyPart: api.bodyPart),
                instructions: api.instructions?.joined(separator: " "),  // full steps for the detail view
                gifUrl: api.gifUrl
            )
        }
    }

    private struct APIExercise: Decodable {
        let id: String
        let name: String
        let bodyPart: String
        let equipment: String
        let gifUrl: String
        let target: String
        let instructions: [String]?
    }

    private func bodyPart(for issue: PostureType?) -> String {
        switch issue {
        case .tlf, .tlb: return "back"      // forward/backward lean
        case .tlr, .tll: return "neck"      // side tilt
        default: return "shoulders"
        }
    }

    private func targetArea(forBodyPart bodyPart: String) -> TargetArea {
        switch bodyPart.lowercased() {
        case "neck": return .neck
        case "back", "waist": return .back
        default: return .fullBody
        }
    }

    // MARK: - Local fallback

    private var eyeRest: BreakExercise {
        BreakExercise(id: "eye-20-20-20", name: "Eye rest (20-20-20)",
                      duration: 20, targetArea: .eyes,
                      instructions: "Look at something ~6 meters away for 20 seconds.")
    }

    private func localExercises(for issue: PostureType?) -> [BreakExercise] {
        let energize = [
            make("Push-ups", 30, .fullBody, "Do 10 push-ups — drop to your knees if needed."),
            make("Bodyweight squats", 30, .fullBody, "Do 15 squats, keeping your back straight.")
        ]
        switch issue {
        case .tlf, .tlb:
            return [
                make("Upper back stretch", 30, .back,
                     "Clasp your hands in front of your chest, push forward, and round your upper back."),
                make("Shoulder rolls", 20, .back,
                     "Slowly roll both shoulders backward 10 times.")
            ] + energize
        case .tlr, .tll:
            return [
                make("Side neck stretch", 20, .neck,
                     "Tilt your head right then left, holding 10 seconds each side."),
                make("Shoulder shrugs", 20, .neck,
                     "Raise both shoulders toward your ears, hold, then release. Repeat 10 times.")
            ] + energize
        default:
            return [
                make("Stand & stretch", 30, .fullBody,
                     "Stand up, reach your arms overhead, and stretch your whole body."),
                make("Slow neck rolls", 20, .neck,
                     "Slowly roll your head clockwise and counter-clockwise.")
            ] + energize
        }
    }

    private func make(_ name: String, _ duration: Int, _ area: TargetArea, _ instructions: String) -> BreakExercise {
        BreakExercise(id: UUID().uuidString, name: name, duration: duration,
                      targetArea: area, instructions: instructions)
    }

    // MARK: - Secrets

    private var apiKey: String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any] else { return nil }
        return dict["ExerciseDBAPIKey"] as? String
    }
}
