// Offline native rendering of the EXACT production FMEngine graph, not a synthesized fixture.
// Run in Debug on an approved Mac/iOS Simulator. Any headroom failure blocks device install.
import AVFoundation
import Foundation
import XCTest
@testable import SensorSynthFM

final class InstrumentAudioRenderTests: XCTestCase {
    @MainActor
    func testNativeADSRAttackSustainAndSnapshottedReleaseRender() throws {
        let instrument = FMEngine()
        defer { instrument.stop() }
        instrument.amplitude = 0.4
        instrument.modulationIndex = 0
        instrument.ampAttack = 0.2
        instrument.ampDecay = 0.15
        instrument.ampSustain = 0.25
        instrument.ampRelease = 0.35
        let renderer = try NativeRenderer(instrument)
        instrument.noteOn(voiceID: 0, frequency: 440)
        let early = try renderer.render(seconds: 0.025)
        _ = try renderer.render(seconds: 0.125)
        let attack = try renderer.render(seconds: 0.04)
        _ = try renderer.render(seconds: 0.4)
        let sustain = try renderer.render(seconds: 0.1)
        XCTAssertGreaterThan(attack.rms, early.rms * 1.5, "Attack must shape real PCM, not merely an observable value")
        XCTAssertGreaterThan(sustain.rms, 0.001)
        XCTAssertLessThan(sustain.rms, attack.rms * 0.6, "Decay/sustain must reduce real PCM amplitude")
        instrument.noteOff(voiceID: 0)
        let token = try XCTUnwrap(instrument.diagnostics(voiceID: 0)).generation
        instrument.ampRelease = 0.02
        instrument.amplitude = 0
        let earlyTail = try renderer.render(seconds: 0.04)
        _ = try renderer.render(seconds: 0.4)
        let lateTail = try renderer.render(seconds: 0.1)
        XCTAssertGreaterThan(earlyTail.rms, 0.0001, "Sensor/base updates must not immediately truncate the snapshotted tail")
        XCTAssertLessThan(lateTail.rms, earlyTail.rms * 0.1)
        instrument.completeRelease(voiceID: 0, generation: token)
        _ = try renderer.render(seconds: 0.08)
        let silence = try renderer.render(seconds: 0.05)
        XCTAssertLessThan(silence.peak, 0.000_01)
        keepEvidence("ADSR early=\(early.rms) attack=\(attack.rms) sustain=\(sustain.rms) earlyTail=\(earlyTail.rms) lateTail=\(lateTail.rms) silencePeak=\(silence.peak)")
        keepAudio(renderer, name: "Production ADSR and release PCM")
    }

    @MainActor
    func testNativeFilterModesChangeActualPCMAndBypassRecovers() throws {
        let instrument = FMEngine()
        defer { instrument.stop() }
        instrument.amplitude = 0.4
        instrument.modulationIndex = 0
        instrument.ampAttack = 0.005
        instrument.ampDecay = 0.005
        instrument.ampSustain = 1
        let renderer = try NativeRenderer(instrument)
        instrument.noteOn(voiceID: 0, frequency: 1000)
        _ = try renderer.render(seconds: 0.2)
        let dry = try renderer.render(seconds: 0.1)
        XCTAssertGreaterThan(dry.rms, 0.01, "Production graph must render audible PCM")
        instrument.filterResonance = 0
        instrument.filterCutoff = 100
        instrument.setFilter(mode: .lowPass, bypassed: false)
        _ = try renderer.render(seconds: 0.3)
        let lp = try renderer.render(seconds: 0.1)
        XCTAssertLessThan(lp.rms, dry.rms * 0.2)
        instrument.filterCutoff = 5000
        instrument.setFilter(mode: .highPass, bypassed: false)
        _ = try renderer.render(seconds: 0.3)
        let hp = try renderer.render(seconds: 0.1)
        XCTAssertLessThan(hp.rms, dry.rms * 0.2)
        instrument.filterCutoff = 1000
        instrument.filterResonance = 1
        instrument.setFilter(mode: .bandPass, bypassed: false)
        _ = try renderer.render(seconds: 0.3)
        let bp = try renderer.render(seconds: 0.1)
        XCTAssertGreaterThan(bp.rms, dry.rms * 0.3)
        instrument.filterCutoff = 50
        _ = try renderer.render(seconds: 0.3)
        let bpReject = try renderer.render(seconds: 0.1)
        XCTAssertLessThan(bpReject.rms, dry.rms * 0.2)
        instrument.setFilter(mode: .bandPass, bypassed: true)
        _ = try renderer.render(seconds: 0.2)
        let recovered = try renderer.render(seconds: 0.1)
        XCTAssertEqual(recovered.rms, dry.rms, accuracy: dry.rms * 0.03)
        keepEvidence("Filter RMS dry=\(dry.rms) LP=\(lp.rms) HP=\(hp.rms) BP=\(bp.rms) BP-reject=\(bpReject.rms) recovered=\(recovered.rms)")
        keepAudio(renderer, name: "Production LP HP BP and bypass PCM")
    }

    @MainActor
    func testTenVoiceWorstCaseOutputAndReleaseAllRemainFiniteAndBelowCeiling() throws {
        let instrument = FMEngine()
        defer { instrument.stop() }
        instrument.amplitude = 1
        instrument.modulationIndex = 10
        instrument.modulatorRatio = 20
        instrument.ampSustain = 1
        let renderer = try NativeRenderer(instrument)
        // Coherent unison attacks are a more demanding sum than an ordinary chord.
        for id in 0..<FMEngine.voiceCapacity { instrument.noteOn(voiceID: id, frequency: 440) }
        var evidence: [String] = []
        let bypassed = try renderer.render(seconds: 0.25)
        XCTAssertGreaterThan(bypassed.rms, 0.01)
        XCTAssertLessThanOrEqual(bypassed.peak, 0.95, "Includes initial attack transient; do not waive this gate")
        evidence.append("bypass peak=\(bypassed.peak) rms=\(bypassed.rms)")
        for mode in FilterMode.allCases {
            for cutoff in [20.0, 600.0, 18_000.0] {
                for resonance in [0.0, 1.0] {
                    instrument.filterCutoff = cutoff
                    instrument.filterResonance = resonance
                    instrument.setFilter(mode: mode, bypassed: false)
                    let pcm = try renderer.render(seconds: 0.25)
                    // No warm-up exclusion: switching transients count too.
                    XCTAssertLessThanOrEqual(pcm.peak, 0.95, "Unsafe output for \(mode) cutoff \(cutoff) resonance \(resonance)")
                    evidence.append("\(mode.rawValue) cutoff=\(cutoff) res=\(resonance) peak=\(pcm.peak) rms=\(pcm.rms)")
                }
            }
        }
        instrument.noteOff(voiceID: 0)
        instrument.releaseAllVoices()
        _ = try renderer.render(seconds: 0.08) // native limiter pipeline drain, no envelope wait
        let silence = try renderer.render(seconds: 0.05)
        XCTAssertLessThan(silence.peak, 0.000_01)
        evidence.append("releaseAll silencePeak=\(silence.peak)")
        keepEvidence(evidence.joined(separator: "\n"))
        keepAudio(renderer, name: "Production ten-voice safety sweep PCM")
    }

    private func keepEvidence(_ text: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = "Native production graph render metrics"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func keepAudio(_ renderer: NativeRenderer, name: String) {
        let attachment = XCTAttachment(contentsOfFile: renderer.finishRecording())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
private final class NativeRenderer {
    private let engine: AVAudioEngine
    private let buffer: AVAudioPCMBuffer
    private let sampleRate: Double
    private let recordingURL: URL
    private var recordingFile: AVAudioFile?

    init(_ instrument: FMEngine) throws {
        let engine = instrument.verificationAudioEngine
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let recordingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SSFM-native-\(UUID().uuidString).wav")
        let recordingFile = try AVAudioFile(forWriting: recordingURL, settings: format.settings)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 512))
        self.engine = engine
        self.buffer = buffer
        self.sampleRate = format.sampleRate
        self.recordingURL = recordingURL
        self.recordingFile = recordingFile
        try engine.start() // native offline pull only; no AVAudioSession, sensors or speaker
    }

    struct Metrics {
        let rms: Double
        let peak: Double
    }

    func finishRecording() -> URL {
        recordingFile = nil // close/flush the WAV before attaching it to the xcresult
        return recordingURL
    }

    func render(seconds: Double) throws -> Metrics {
        var remaining = AVAudioFrameCount((seconds * sampleRate).rounded())
        var sumSquares = 0.0
        var peak = 0.0
        var samples = 0
        while remaining > 0 {
            let requested = min(remaining, 512)
            let status = try engine.renderOffline(requested, to: buffer)
            guard status == .success else {
                throw NSError(domain: "SSFM.NativeRender", code: Int(status.rawValue),
                              userInfo: [NSLocalizedDescriptionKey: "Native offline rendering failed: \(status)"])
            }
            guard buffer.frameLength == requested, let channels = buffer.floatChannelData else {
                throw NSError(domain: "SSFM.NativeRender", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Native renderer returned incomplete/non-Float PCM"])
            }
            for channel in 0..<Int(buffer.format.channelCount) {
                for frame in 0..<Int(buffer.frameLength) {
                    let sample = Double(channels[channel][frame])
                    guard sample.isFinite else {
                        throw NSError(domain: "SSFM.NativeRender", code: -2,
                                      userInfo: [NSLocalizedDescriptionKey: "Non-finite sample in production audio graph"])
                    }
                    peak = max(peak, abs(sample))
                    sumSquares += sample * sample
                    samples += 1
                }
            }
            try recordingFile?.write(from: buffer)
            remaining -= requested
        }
        return Metrics(rms: sqrt(sumSquares / Double(max(samples, 1))), peak: peak)
    }
}
