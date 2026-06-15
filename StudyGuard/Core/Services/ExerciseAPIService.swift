//
//  ExerciseAPIService.swift
//  StudyGuard
//

import Foundation

/// Supplies break exercises matched to the session's dominant posture issue.
///
/// Milestone 5 uses a curated local set (no extra API key needed). The interface
/// is async so a real ExerciseDB/Ninjas API — or the BreakCoach agent — can be
/// swapped in later without touching callers.
final class ExerciseAPIService {

    static let shared = ExerciseAPIService()
    private init() {}

    /// Returns a short break routine for the given dominant posture issue.
    func routine(for issue: PostureType?, breakMinutes: Int) async -> [BreakExercise] {
        var exercises = exercises(for: issue)
        // Always include an eye-rest exercise (20-20-20 rule).
        exercises.append(
            BreakExercise(id: UUID().uuidString, name: "Istirahat mata (20-20-20)",
                          duration: 20, targetArea: .eyes,
                          instructions: "Lihat objek sejauh ~6 meter selama 20 detik.")
        )
        return exercises
    }

    private func exercises(for issue: PostureType?) -> [BreakExercise] {
        switch issue {
        case .tlf, .tlb: // forward / backward lean -> back + neck
            return [
                make("Peregangan punggung atas", 30, .back,
                     "Tautkan jari di depan dada, dorong ke depan, lengkungkan punggung atas."),
                make("Putar bahu ke belakang", 20, .back,
                     "Putar kedua bahu perlahan ke belakang 10 kali.")
            ]
        case .tlr, .tll: // side tilt -> neck + shoulders
            return [
                make("Tekuk leher ke samping", 20, .neck,
                     "Miringkan kepala ke kanan lalu kiri, tahan 10 detik tiap sisi."),
                make("Angkat & turunkan bahu", 20, .neck,
                     "Angkat kedua bahu ke arah telinga, tahan, lalu lepas. Ulangi 10 kali.")
            ]
        default: // good posture / unknown -> light full-body reset
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
}
