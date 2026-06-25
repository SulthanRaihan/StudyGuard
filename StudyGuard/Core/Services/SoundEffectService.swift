//
//  SoundEffectService.swift
//  StudyGuard
//

import AVFoundation

/// Plays short one-shot sound effects (e.g. a "bungkuk"/slouch cue) bundled as
/// audio files. Relies on the audio session category already configured by
/// `VoiceAlertService` (so these play even with the device on silent, matching
/// the voice coaching behavior) -- doesn't reconfigure the session itself.
final class SoundEffectService {

    static let shared = SoundEffectService()
    private init() {}

    var isEnabled = true

    /// Keeps a strong reference per sound so playback isn't cut off if another
    /// effect fires before this one finishes.
    private var players: [String: AVAudioPlayer] = [:]

    /// Plays the named sound effect once. `name` should match a bundled audio
    /// file (without extension) — tries mp3/wav/caf/m4a in that order.
    func play(_ name: String) {
        guard isEnabled else { return }
        guard let url = ["mp3", "wav", "caf", "m4a"]
            .lazy
            .compactMap({ Bundle.main.url(forResource: name, withExtension: $0) })
            .first
        else {
            print("⚠️ Sound effect '\(name)' not found in the app bundle.")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            players[name] = player
            player.play()
        } catch {
            print("⚠️ Failed to play sound effect '\(name)': \(error)")
        }
    }
}
