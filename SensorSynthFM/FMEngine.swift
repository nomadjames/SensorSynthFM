// FMEngine.swift
// SensorSynthFM
//
// AudioKit FM engine with a pre-connected, fixed voice bank. Touch pitch is
// stored per voice; global FM controls are applied coherently to every voice.

import AudioKit
import SoundpipeAudioKit
import AVFoundation
import Foundation
import Observation

public struct FMVoiceState: Equatable, Sendable, Identifiable {
    public let id: Int
    public var isActive: Bool
    public var frequency: Double
}

@Observable
final class FMEngine {
    static let voiceCapacity = 10

    // MARK: - Observable state

    var isRunning = false
    var isPlaying = false
    var activeVoiceCount = 0
    private(set) var voiceStates: [FMVoiceState] = (0..<FMEngine.voiceCapacity).map {
        FMVoiceState(id: $0, isActive: false, frequency: 440)
    }
    private(set) var lastPitchRampMilliseconds = 0.0

    /// Legacy/global carrier value. Active touch voices retain their own pitch.
    var carrierFrequency: Double = 440.0 { didSet { applyParameters() } }
    var modulatorRatio: Double = 1.0 { didSet { applyParameters() } }
    var modulationIndex: Double = 1.0 { didSet { applyParameters() } }
    var amplitude: Double = 0.5 { didSet { applyParameters() } }

    // MARK: - Fixed graph

    private final class VoiceNode {
        let id: Int
        let oscillator: FMOscillator
        var frequency: Double = 440
        var isActive = false

        init(id: Int) {
            self.id = id
            oscillator = FMOscillator()
        }
    }

    private let audioEngine = AudioEngine()
    private let voiceBank: [VoiceNode]
    private var mixer: Mixer?

    init() {
        voiceBank = (0..<Self.voiceCapacity).map { VoiceNode(id: $0) }
    }

    // MARK: - Lifecycle

    /// Creates and connects every voice once. Touches only start/stop existing nodes.
    func start(allowMicrophoneInput: Bool = false) {
        guard !isRunning else { return }

        do {
            if allowMicrophoneInput {
                try AVAudioSession.sharedInstance().setCategory(
                    .playAndRecord,
                    mode: .measurement,
                    options: [.defaultToSpeaker, .allowBluetoothHFP]
                )
            } else {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            }
            try AVAudioSession.sharedInstance().setActive(true)

            let graphMixer = Mixer()
            for voice in voiceBank {
                configure(voice)
                graphMixer.addInput(voice.oscillator)
            }
            mixer = graphMixer
            audioEngine.output = graphMixer
            try audioEngine.start()
            isRunning = true
        } catch {
            print("[FMEngine] Failed to start: \(error.localizedDescription)")
        }
    }

    func stop() {
        releaseAllVoices()
        voiceBank.forEach { $0.oscillator.stop() }
        audioEngine.stop()
        mixer = nil
        isRunning = false
    }

    // MARK: - Legacy note API

    /// Preserved for the accepted matrix/FM test surface.
    func noteOn(frequency: Double? = nil) {
        noteOn(voiceID: 0, frequency: frequency ?? carrierFrequency)
    }

    /// Preserved stop-all behavior for the accepted matrix/FM test surface.
    func noteOff() {
        releaseAllVoices()
    }

    // MARK: - Per-voice note API

    func noteOn(voiceID: Int, frequency: Double) {
        guard let voice = voice(for: voiceID) else { return }
        voice.frequency = max(frequency, 20)
        voice.isActive = true
        configure(voice)
        voice.oscillator.start()
        publishVoiceState()
    }

    func noteOff(voiceID: Int) {
        guard let voice = voice(for: voiceID), voice.isActive else { return }
        voice.isActive = false
        voice.oscillator.stop()
        publishVoiceState()
        applyParameters()
    }

    func setFrequency(voiceID: Int, frequency: Double, rampMilliseconds: Double = 20.0) {
        guard let voice = voice(for: voiceID), voice.isActive else { return }
        voice.frequency = max(frequency, 20)
        // FMOscillator exposes an AUParameter-backed frequency setter. Updating
        // that parameter in place preserves the voice/envelope identity and is
        // the smallest anti-click transition available without a new graph node.
        voice.oscillator.baseFrequency = AUValue(voice.frequency)
        lastPitchRampMilliseconds = rampMilliseconds
        publishVoiceState()
    }

    func releaseAllVoices() {
        for voice in voiceBank where voice.isActive {
            voice.isActive = false
            voice.oscillator.stop()
        }
        publishVoiceState()
    }

    // MARK: - Parameters

    private func configure(_ voice: VoiceNode) {
        voice.oscillator.baseFrequency = AUValue(voice.isActive ? voice.frequency : carrierFrequency)
        voice.oscillator.carrierMultiplier = 1.0
        voice.oscillator.modulatingMultiplier = AUValue(modulatorRatio)
        voice.oscillator.modulationIndex = AUValue(modulationIndex)
        voice.oscillator.amplitude = AUValue(voice.isActive ? amplitude : 0.0)
    }

    private func applyParameters() {
        for voice in voiceBank {
            voice.oscillator.carrierMultiplier = 1.0
            voice.oscillator.modulatingMultiplier = AUValue(modulatorRatio)
            voice.oscillator.modulationIndex = AUValue(modulationIndex)
            voice.oscillator.amplitude = AUValue(voice.isActive ? amplitude : 0.0)
            if !voice.isActive {
                voice.oscillator.baseFrequency = AUValue(carrierFrequency)
            }
        }
    }

    private func voice(for id: Int) -> VoiceNode? {
        guard voiceBank.indices.contains(id) else { return nil }
        return voiceBank[id]
    }

    private func publishVoiceState() {
        voiceStates = voiceBank.map {
            FMVoiceState(id: $0.id, isActive: $0.isActive, frequency: $0.frequency)
        }
        activeVoiceCount = voiceBank.reduce(into: 0) { count, voice in
            if voice.isActive { count += 1 }
        }
        isPlaying = activeVoiceCount > 0
    }
}
