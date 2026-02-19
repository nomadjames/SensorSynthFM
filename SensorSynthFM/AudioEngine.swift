// AudioEngine.swift
// SensorSynthFM
//
// Minimal audio engine using Apple's native AVAudioEngine.
// Generates a sine wave via AVAudioSourceNode — no external dependencies.
// This proves audio output works. AudioKit replaces this for FM synthesis later.

import AVFoundation
import Foundation

@Observable
final class SynthEngine {

    // MARK: - Observable state

    var isRunning = false
    var isPlaying = false

    var frequency: Double = 440.0
    var amplitude: Double = 0.5

    // MARK: - Private audio state

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    /// Phase accumulator for the sine wave (accessed from audio thread only).
    private var phase: Double = 0.0

    // MARK: - Engine lifecycle

    func start() {
        guard !isRunning else { return }

        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate

        // Create a source node that generates audio samples directly.
        // This closure runs on the audio thread — no allocations, no locks.
        sourceNode = AVAudioSourceNode { [unowned self] _, _, frameCount, audioBufferList in
            let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let freq = self.frequency
            let amp = self.isPlaying ? self.amplitude : 0.0
            let phaseIncrement = 2.0 * Double.pi * freq / sampleRate

            for frame in 0..<Int(frameCount) {
                let sample = Float(sin(self.phase) * amp)
                self.phase += phaseIncrement
                if self.phase > 2.0 * Double.pi {
                    self.phase -= 2.0 * Double.pi
                }
                for buffer in bufferList {
                    let channelData = buffer.mData!.assumingMemoryBound(to: Float.self)
                    channelData[frame] = sample
                }
            }
            return noErr
        }

        guard let sourceNode else { return }

        let format = engine.outputNode.outputFormat(forBus: 0)
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            isRunning = true
        } catch {
            print("[SynthEngine] Failed to start: \(error.localizedDescription)")
        }
    }

    func stop() {
        isPlaying = false
        engine.stop()
        if let node = sourceNode {
            engine.detach(node)
            sourceNode = nil
        }
        isRunning = false
    }

    // MARK: - Note control

    func noteOn(frequency: Double? = nil) {
        if let freq = frequency {
            self.frequency = freq
        }
        isPlaying = true
    }

    func noteOff() {
        isPlaying = false
    }
}
