//
//  VoiceAlertService.swift
//  StudyGuard
//

import AVFoundation

/// Speaks short coaching alerts via `AVSpeechSynthesizer`, with a per-message
/// cooldown so the same alert can't repeat too often (keeps coaching from
/// becoming nagging).
final class VoiceAlertService {

    var isEnabled = true
    var language = "id-ID"

    private let synthesizer = AVSpeechSynthesizer()
    private let defaultCooldown: TimeInterval = 30
    private var lastSpoken: [String: Date] = [:]

    init() {
        // Mix with other audio and duck it briefly; we only ever play short TTS.
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers]
        )
    }

    /// Speaks `text`, unless the same `key` spoke within its cooldown window.
    func speak(_ text: String, key: String, cooldown: TimeInterval? = nil) {
        guard isEnabled else { return }
        let window = cooldown ?? defaultCooldown
        if let last = lastSpoken[key], Date().timeIntervalSince(last) < window { return }
        lastSpoken[key] = Date()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        synthesizer.speak(utterance)
    }

    /// Speaks immediately, ignoring cooldowns (e.g. break announcements).
    func announce(_ text: String) {
        guard isEnabled else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
