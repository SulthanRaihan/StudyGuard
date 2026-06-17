//
//  FocusSoundService.swift
//  StudyGuard
//

import AVFoundation
import Combine

/// Plays soft brown-noise ambience to aid focus during a session. Generated on
/// the fly (no audio asset needed). Tune `gain` if it's too loud/quiet on-device.
final class FocusSoundService: ObservableObject {

    static let shared = FocusSoundService()
    private init() {}

    @Published private(set) var isPlaying = false

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var lastSample: Float = 0
    private let gain: Float = 0.18

    func toggle() { isPlaying ? stop() : start() }

    func start() {
        guard !isPlaying else { return }
        let format = engine.outputNode.inputFormat(forBus: 0)

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                // Brown noise = integrated (low-passed) white noise.
                let white = Float.random(in: -1...1)
                self.lastSample = max(-1, min(1, self.lastSample + 0.02 * white))
                let value = self.lastSample * self.gain
                for buffer in buffers {
                    let ptr = UnsafeMutableBufferPointer<Float>(buffer)
                    if frame < ptr.count { ptr[frame] = value }
                }
            }
            return noErr
        }

        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        do {
            try engine.start()
            isPlaying = true
        } catch {
            cleanup()
        }
    }

    func stop() {
        guard isPlaying else { return }
        engine.stop()
        cleanup()
        isPlaying = false
    }

    private func cleanup() {
        if let node = sourceNode { engine.detach(node) }
        sourceNode = nil
    }
}
