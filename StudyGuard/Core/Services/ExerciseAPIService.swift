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

    /// Returns a short break routine for the given dominant posture issue.
    func routine(for issue: PostureType?, breakMinutes: Int) async -> [BreakExercise] {
        var exercises: [BreakExercise] = []

        if let key = apiKey, !key.isEmpty,
           let fetched = try? await fetchExercises(bodyPart: bodyPart(for: issue), key: key),
           !fetched.isEmpty {
            exercises = Array(fetched.prefix(3))
        } else {
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
                instructions: api.instructions?.prefix(2).joined(separator: " "),
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
        BreakExercise(id: "eye-20-20-20", name: "Istirahat mata (20-20-20)",
                      duration: 20, targetArea: .eyes,
                      instructions: "Lihat objek sejauh ~6 meter selama 20 detik.")
    }

    private func localExercises(for issue: PostureType?) -> [BreakExercise] {
        switch issue {
        case .tlf, .tlb:
            return [
                make("Peregangan punggung atas", 30, .back,
                     "Tautkan jari di depan dada, dorong ke depan, lengkungkan punggung atas."),
                make("Putar bahu ke belakang", 20, .back,
                     "Putar kedua bahu perlahan ke belakang 10 kali.")
            ]
        case .tlr, .tll:
            return [
                make("Tekuk leher ke samping", 20, .neck,
                     "Miringkan kepala ke kanan lalu kiri, tahan 10 detik tiap sisi."),
                make("Angkat & turunkan bahu", 20, .neck,
                     "Angkat kedua bahu ke arah telinga, tahan, lalu lepas. Ulangi 10 kali.")
            ]
        default:
            return [
                make("Berdiri & regangkan tubuh", 30, .fullBody,
                     "Berdiri, angkat tangan ke atas, regangkan seluruh tubuh."),
                make("Putar leher perlahan", 20, .neck,
                     "Putar kepala perlahan searah dan berlawanan jarum jam.")
            ]
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
