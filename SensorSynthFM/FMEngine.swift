// Fixed ten-voice FM instrument. All controls/lifecycle calls are main-thread owned.
import AudioKit
import AudioKitEX
import SoundpipeAudioKit
import AVFoundation
import Foundation
import Observation

public struct FMVoiceState: Equatable, Sendable, Identifiable {
    public let id: Int
    public var isActive: Bool
    public var frequency: Double
}

/// Read-only control/graph evidence for native behavior tests; not rendered-audio proof.
struct FMVoiceDiagnostics {
    let generation: UInt64
    let isActive: Bool
    let isReleasing: Bool
    let releaseSeconds: Double?
    let gateOpenCount: Int
    let attack: Double
    let decay: Double
    let sustain: Double
    let release: Double
    let oscillatorAmplitude: Double
    let oscillatorStarted: Bool
    let filterNodeIDs: [ObjectIdentifier]
    let enabledFilters: [Bool]
    let cutoff: Double
    let resonanceDB: Double
    let bandwidthCents: Double
}

@Observable
final class FMEngine {
    static let voiceCapacity = 10
    static let releaseCleanupSlackSeconds = 0.03 // cover a final native render quantum

    private(set) var isRunning = false
    private(set) var isPlaying = false
    private(set) var activeVoiceCount = 0
    private(set) var voiceStates: [FMVoiceState] = (0..<FMEngine.voiceCapacity).map {
        FMVoiceState(id: $0, isActive: false, frequency: 440)
    }
    private(set) var lastPitchRampMilliseconds = 0.0
    private(set) var parameterFrameCount = 0

    // Legacy API remains usable by the existing test views. Bounds are enforced at DSP.
    var carrierFrequency: Double = 440 { didSet { parametersChanged() } }
    var modulatorRatio: Double = 1 { didSet { parametersChanged() } }
    var modulationIndex: Double = 1 { didSet { parametersChanged() } }
    var amplitude: Double = 0.5 { didSet { parametersChanged() } }
    var ampAttack = SensorModulationTarget.ampAttack.defaultValue { didSet { parametersChanged() } }
    var ampDecay = SensorModulationTarget.ampDecay.defaultValue { didSet { parametersChanged() } }
    var ampSustain = SensorModulationTarget.ampSustain.defaultValue { didSet { parametersChanged() } }
    var ampRelease = SensorModulationTarget.ampRelease.defaultValue { didSet { parametersChanged() } }
    var filterCutoff = SensorModulationTarget.filterCutoff.defaultValue { didSet { parametersChanged() } }
    var filterResonance = SensorModulationTarget.filterResonance.defaultValue { didSet { parametersChanged() } }
    var filterMode: FilterMode = .lowPass { didSet { parametersChanged() } }
    var filterBypassed = true { didSet { parametersChanged() } }
    private var applyingFrame = false

    private final class VoiceNode {
        let id: Int
        let oscillator: FMOscillator
        let envelope: AmplitudeEnvelope
        let lowPass: LowPassFilter
        let highPass: HighPassFilter
        let bandPass: BandPassFilter
        var frequency: Double = 440
        var isActive = false
        var generation: UInt64 = 0
        var gateOpenCount = 0
        var releaseSeconds: Double?
        var releaseWorkItem: DispatchWorkItem?

        init(id: Int) {
            let oscillator = FMOscillator()
            let envelope = AmplitudeEnvelope(oscillator,
                attackDuration: AUValue(SensorModulationTarget.ampAttack.defaultValue),
                decayDuration: AUValue(SensorModulationTarget.ampDecay.defaultValue),
                sustainLevel: AUValue(SensorModulationTarget.ampSustain.defaultValue),
                releaseDuration: AUValue(SensorModulationTarget.ampRelease.defaultValue))
            let lowPass = LowPassFilter(envelope)
            let highPass = HighPassFilter(lowPass)
            let bandPass = BandPassFilter(highPass)
            self.id = id
            self.oscillator = oscillator
            self.envelope = envelope
            self.lowPass = lowPass
            self.highPass = highPass
            self.bandPass = bandPass
            lowPass.stop()
            highPass.stop()
            bandPass.stop()
            oscillator.stop()
            envelope.closeGate()
        }
    }

    private let audioEngine = AudioEngine()
    private let voiceBank: [VoiceNode]
    private let limiter: PeakLimiter

    // Internal test seam: native offline tests exercise this exact graph, without a speaker/session.
    // No production UI/control path invokes manual rendering.
    var verificationAudioEngine: AVAudioEngine { audioEngine.avEngine }

    init() {
        let voiceBank = (0..<Self.voiceCapacity).map { VoiceNode(id: $0) }
        let graphMixer = Mixer()
        for voice in voiceBank {
            graphMixer.addInput(voice.bandPass)
        }
        // Native last-line safety, not a substitute for worst-case render testing.
        // Unity pre-gain preserves bypassed single-note timbre below the limiter ceiling.
        let limiter = PeakLimiter(graphMixer, attackTime: 0.001, decayTime: 0.03, preGain: 0)
        let outputMixer = Mixer(limiter)
        outputMixer.volume = 0.8 // fixed post-limiter headroom; not a user-modulatable gain
        self.voiceBank = voiceBank
        self.limiter = limiter
        audioEngine.output = outputMixer
        applyParameters()
    }

    func start(allowMicrophoneInput: Bool = false) {
        guard !isRunning else { return }
        do {
            if allowMicrophoneInput {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .measurement,
                                                                options: [.defaultToSpeaker, .allowBluetoothHFP])
            } else {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            }
            try AVAudioSession.sharedInstance().setActive(true)
            try audioEngine.start()
            isRunning = true
        } catch {
            releaseAllVoices()
            audioEngine.stop()
            print("[FMEngine] Failed to start: \(error.localizedDescription)")
        }
    }

    func stop() {
        releaseAllVoices()
        audioEngine.stop()
        isRunning = false
    }

    // MARK: - Legacy note API
    func noteOn(frequency: Double? = nil) {
        noteOn(voiceID: 0, frequency: frequency ?? carrierFrequency)
    }
    func noteOff() { releaseAllVoices() }

    // MARK: - Per-voice note API
    func noteOn(voiceID: Int, frequency: Double) {
        guard frequency.isFinite, let voice = voice(for: voiceID) else { return }
        voice.generation &+= 1
        voice.releaseWorkItem?.cancel()
        voice.releaseWorkItem = nil
        voice.releaseSeconds = nil
        voice.frequency = min(max(frequency, 20), 20_000)
        voice.isActive = true
        voice.oscillator.baseFrequency = AUValue(voice.frequency)
        applyParameters()
        // Reset native envelope state on real note-on (including a reused release/held voice),
        // never on sensor frames or pitch remaps. No custom DSP/render callback.
        voice.envelope.closeGate()
        voice.envelope.reset()
        voice.lowPass.reset()
        voice.highPass.reset()
        voice.bandPass.reset()
        voice.oscillator.start()
        voice.envelope.openGate()
        voice.gateOpenCount += 1
        publishVoiceState()
    }

    func noteOff(voiceID: Int) {
        guard let voice = voice(for: voiceID), voice.isActive else { return }
        voice.isActive = false
        let releaseSeconds = SensorModulationTarget.ampRelease.clamp(ampRelease)
        voice.releaseSeconds = releaseSeconds
        voice.envelope.releaseDuration = AUValue(releaseSeconds)
        voice.envelope.closeGate()
        let generation = voice.generation
        let release = DispatchWorkItem { [weak self] in
            self?.completeRelease(voiceID: voiceID, generation: generation)
        }
        voice.releaseWorkItem = release
        DispatchQueue.main.asyncAfter(deadline: .now() + releaseSeconds + Self.releaseCleanupSlackSeconds,
                                      execute: release)
        publishVoiceState()
    }

    /// Token checks, not DispatchWorkItem.cancel alone, prevent old cleanup killing a reused voice.
    func completeRelease(voiceID: Int, generation: UInt64) {
        guard let voice = voice(for: voiceID), voice.generation == generation,
              !voice.isActive, voice.releaseWorkItem != nil else { return }
        voice.oscillator.stop()
        voice.releaseWorkItem = nil
        voice.releaseSeconds = nil
        // Also clear native filter history so silence does not leave an orphaned resonant tail.
        voice.lowPass.reset()
        voice.highPass.reset()
        voice.bandPass.reset()
    }

    func setFrequency(voiceID: Int, frequency: Double, rampMilliseconds: Double = 20.0) {
        guard frequency.isFinite, let voice = voice(for: voiceID), voice.isActive else { return }
        voice.frequency = min(max(frequency, 20), 20_000)
        let boundedRampMilliseconds = rampMilliseconds.isFinite ? min(max(rampMilliseconds, 0), 5_000) : 0
        voice.oscillator.$baseFrequency.ramp(to: AUValue(voice.frequency),
                                           duration: Float(boundedRampMilliseconds / 1000.0))
        lastPitchRampMilliseconds = boundedRampMilliseconds
        publishVoiceState()
    }

    func releaseAllVoices() {
        for voice in voiceBank {
            voice.generation &+= 1
            voice.releaseWorkItem?.cancel()
            voice.releaseWorkItem = nil
            voice.releaseSeconds = nil
            voice.isActive = false
            voice.envelope.closeGate()
            voice.oscillator.stop()
            voice.envelope.reset()
            voice.lowPass.reset()
            voice.highPass.reset()
            voice.bandPass.reset()
        }
        limiter.reset()
        publishVoiceState()
    }

    // MARK: - Parameters
    func apply(output: SensorModulationOutput, preserveTouchPitch: Bool) {
        applyingFrame = true
        if !preserveTouchPitch { carrierFrequency = output.carrierFrequency }
        modulatorRatio = output.modulatorRatio
        modulationIndex = output.modulationIndex
        amplitude = output.amplitude
        ampAttack = output.value(for: .ampAttack)
        ampDecay = output.value(for: .ampDecay)
        ampSustain = output.value(for: .ampSustain)
        ampRelease = output.value(for: .ampRelease)
        filterCutoff = output.value(for: .filterCutoff)
        filterResonance = output.value(for: .filterResonance)
        applyingFrame = false
        applyParameters()
        parameterFrameCount += 1
    }

    func setFilter(mode: FilterMode, bypassed: Bool) {
        applyingFrame = true
        filterMode = mode
        filterBypassed = bypassed
        applyingFrame = false
        applyParameters()
    }
    private func parametersChanged() {
        if !applyingFrame { applyParameters() }
    }
    private func applyParameters() {
        for voice in voiceBank {
            voice.oscillator.carrierMultiplier = 1
            voice.oscillator.modulatingMultiplier = AUValue(SensorModulationTarget.modulatorRatio.clamp(modulatorRatio))
            voice.oscillator.modulationIndex = AUValue(SensorModulationTarget.modulationIndex.clamp(modulationIndex))
            // Freeze amplitude AND ADSR for a releasing voice. Sensor ticks cannot shorten
            // its snapshotted native release or reset/retrigger the envelope gate.
            if voice.releaseWorkItem == nil {
                voice.oscillator.amplitude = AUValue(voice.isActive ? SensorModulationTarget.amplitude.clamp(amplitude) : 0)
                voice.envelope.attackDuration = AUValue(SensorModulationTarget.ampAttack.clamp(ampAttack))
                voice.envelope.decayDuration = AUValue(SensorModulationTarget.ampDecay.clamp(ampDecay))
                voice.envelope.sustainLevel = AUValue(SensorModulationTarget.ampSustain.clamp(ampSustain))
                voice.envelope.releaseDuration = AUValue(SensorModulationTarget.ampRelease.clamp(ampRelease))
            }
            if !voice.isActive, voice.releaseWorkItem == nil {
                voice.oscillator.baseFrequency = AUValue(SensorModulationTarget.carrierFrequency.clamp(carrierFrequency))
            }
            let cutoff = AUValue(SensorModulationTarget.filterCutoff.clamp(filterCutoff))
            voice.lowPass.cutoffFrequency = cutoff
            voice.highPass.cutoffFrequency = cutoff
            voice.bandPass.centerFrequency = cutoff
            let resonance = SensorModulationTarget.filterResonance.clamp(filterResonance)
            voice.lowPass.resonance = AUValue(FilterMode.resonanceDecibels(resonance))
            voice.highPass.resonance = AUValue(FilterMode.resonanceDecibels(resonance))
            voice.bandPass.bandwidth = AUValue(FilterMode.bandwidthCents(resonance))
            setEnabled(voice.lowPass, !filterBypassed && filterMode == .lowPass)
            setEnabled(voice.highPass, !filterBypassed && filterMode == .highPass)
            setEnabled(voice.bandPass, !filterBypassed && filterMode == .bandPass)
        }
    }
    private func setEnabled(_ node: Node, _ enabled: Bool) {
        guard node.isStarted != enabled else { return }
        if enabled { node.start() } else { node.stop() }
    }
    private func voice(for id: Int) -> VoiceNode? {
        guard voiceBank.indices.contains(id) else { return nil }
        return voiceBank[id]
    }
    private func publishVoiceState() {
        voiceStates = voiceBank.map { FMVoiceState(id: $0.id, isActive: $0.isActive, frequency: $0.frequency) }
        activeVoiceCount = voiceBank.reduce(into: 0) { count, voice in
            if voice.isActive { count += 1 }
        }
        isPlaying = activeVoiceCount > 0
    }
    func diagnostics(voiceID: Int) -> FMVoiceDiagnostics? {
        guard let voice = voice(for: voiceID) else { return nil }
        return FMVoiceDiagnostics(generation: voice.generation, isActive: voice.isActive,
                                  isReleasing: voice.releaseWorkItem != nil, releaseSeconds: voice.releaseSeconds,
                                  gateOpenCount: voice.gateOpenCount,
                                  attack: Double(voice.envelope.attackDuration), decay: Double(voice.envelope.decayDuration),
                                  sustain: Double(voice.envelope.sustainLevel), release: Double(voice.envelope.releaseDuration),
                                  oscillatorAmplitude: Double(voice.oscillator.amplitude),
                                  oscillatorStarted: voice.oscillator.isStarted,
                                  filterNodeIDs: [ObjectIdentifier(voice.lowPass), ObjectIdentifier(voice.highPass), ObjectIdentifier(voice.bandPass)],
                                  enabledFilters: [voice.lowPass.isStarted, voice.highPass.isStarted, voice.bandPass.isStarted],
                                  cutoff: Double(voice.bandPass.centerFrequency), resonanceDB: Double(voice.lowPass.resonance),
                                  bandwidthCents: Double(voice.bandPass.bandwidth))
    }
}

extension FMEngine: SensorFMParameterSink {}
