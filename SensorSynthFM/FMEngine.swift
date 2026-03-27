// FMEngine.swift
// SensorSynthFM
//
// AudioKit-based FM synthesis engine. Replaces the native AVAudioEngine
// sine wave from Session 1. Uses AudioKit's FMOscillator node for real
// FM synthesis with carrier frequency, modulator ratio, modulation index,
// and amplitude controls.
//
// All parameter updates go through AudioKit's node properties, which are
// backed by AUParameter and are audio-thread safe.

import AudioKit
import AVFoundation
import Foundation

@Observable
final class FMEngine {

    // MARK: - Observable state (UI-bound)

    /// Whether the AudioKit engine is running (audio session active).
    var isRunning = false

    /// Whether a note is currently sounding.
    var isPlaying = false

    /// Carrier frequency in Hz. Range: 20–2000.
    var carrierFrequency: Double = 440.0 {
        didSet { applyParameters() }
    }

    /// Modulator frequency expressed as a ratio to carrier. Range: 0.1–20.0.
    /// Actual modulator frequency = carrierFrequency * modulatorRatio.
    var modulatorRatio: Double = 1.0 {
        didSet { applyParameters() }
    }

    /// FM modulation index. Controls brightness/harmonic content. Range: 0–10.
    var modulationIndex: Double = 1.0 {
        didSet { applyParameters() }
    }

    /// Output amplitude. Range: 0–1.
    var amplitude: Double = 0.5 {
        didSet { applyParameters() }
    }

    // MARK: - AudioKit internals

    private let audioEngine = AudioEngine()
    private var fmOscillator: FMOscillator?

    // MARK: - Engine lifecycle

    /// Start the AudioKit engine and create the FM oscillator node.
    /// Call this once when the view appears.
    func start() {
        guard !isRunning else { return }

        do {
            // Configure audio session for playback
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            // Create the FM oscillator with initial parameter values
            let osc = FMOscillator()
            osc.baseFrequency = AUValue(carrierFrequency)
            osc.carrierMultiplier = 1.0  // Carrier = baseFrequency * 1.0
            osc.modulatingMultiplier = AUValue(modulatorRatio)
            osc.modulationIndex = AUValue(modulationIndex)
            osc.amplitude = AUValue(amplitude)

            self.fmOscillator = osc

            // Connect oscillator to the engine output
            audioEngine.output = osc

            try audioEngine.start()
            isRunning = true
        } catch {
            print("[FMEngine] Failed to start: \(error.localizedDescription)")
        }
    }

    /// Stop the AudioKit engine and tear down the audio session.
    func stop() {
        isPlaying = false
        fmOscillator?.stop()
        audioEngine.stop()
        isRunning = false
    }

    // MARK: - Note control

    /// Start sounding. Optionally set carrier frequency at the same time.
    func noteOn(frequency: Double? = nil) {
        if let freq = frequency {
            carrierFrequency = freq
        }
        fmOscillator?.start()
        isPlaying = true
    }

    /// Stop sounding.
    func noteOff() {
        fmOscillator?.stop()
        isPlaying = false
    }

    // MARK: - Parameter application

    /// Push current parameter values to the AudioKit oscillator node.
    /// AudioKit's FMOscillator properties are AUParameter-backed,
    /// so these updates are audio-thread safe.
    private func applyParameters() {
        guard let osc = fmOscillator else { return }

        osc.baseFrequency = AUValue(carrierFrequency)
        osc.carrierMultiplier = 1.0
        osc.modulatingMultiplier = AUValue(modulatorRatio)
        osc.modulationIndex = AUValue(modulationIndex)
        osc.amplitude = AUValue(isPlaying ? amplitude : 0.0)
    }
}
