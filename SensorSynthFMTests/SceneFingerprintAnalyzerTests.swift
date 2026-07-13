// SceneFingerprintAnalyzerTests.swift
// SensorSynthFMTests

import Testing
@testable import SensorSynthFM

@MainActor
struct SceneFingerprintAnalyzerTests {
    @Test func quietStillWindowMakesStableLowEnergyFingerprint() {
        let fingerprint = captureWindow { time in
            sample(time: time, micAmplitude: 0.01, micLow: 0.001, micMid: 0.001, micHigh: 0.001)
        }

        #expect(fingerprint.stableSeedFields.deviceStillnessMean > 0.95)
        #expect(fingerprint.stableSeedFields.roomEnergyMean < 0.05)
        #expect(fingerprint.stableSeedFields.impactP95 < 0.05)
    }

    @Test func impactSpikesAndDecays() {
        let analyzer = SceneFingerprintAnalyzer()
        analyzer.push(sample: sample(time: 0))
        let before = analyzer.currentLiveFields.surfaceImpactEnvelope

        analyzer.push(sample: sample(time: 0.05, accelX: 0.9))
        let spike = analyzer.currentLiveFields.surfaceImpactEnvelope

        for frame in 1...30 {
            analyzer.push(sample: sample(time: 0.05 + Double(frame) / 60.0))
        }

        #expect(spike > before + 0.5)
        #expect(analyzer.currentLiveFields.surfaceImpactEnvelope < spike)
    }

    @Test func sustainedMotionRaisesSurfaceVibration() {
        let analyzer = SceneFingerprintAnalyzer()

        for frame in 0..<60 {
            analyzer.push(sample: sample(
                time: Double(frame) / 60.0,
                accelX: frame.isMultiple(of: 2) ? 0.60 : 0.40,
                gyroY: 0.60
            ))
        }

        #expect(analyzer.currentLiveFields.surfaceVibrationEnvelope > 0.10)
    }

    @Test func spectralRatiosRaiseBrightnessAndBassPressure() {
        let bright = captureWindow { time in
            sample(time: time, micAmplitude: 0.4, micLow: 0.01, micMid: 0.02, micHigh: 0.20)
        }
        let bass = captureWindow { time in
            sample(time: time, micAmplitude: 0.4, micLow: 0.20, micMid: 0.02, micHigh: 0.01)
        }

        #expect(bright.stableSeedFields.spectralBrightnessMean > 0.80)
        #expect(bass.stableSeedFields.bassPressureMean > 0.80)
    }

    @Test func stableSeedHashIgnoresVolatileLiveFields() {
        let first = captureWindow { time in sample(time: time, micAmplitude: 0.2, micLow: 0.03, micMid: 0.04, micHigh: 0.05) }
        let second = captureWindow { time in sample(time: time, micAmplitude: 0.2, micLow: 0.03, micMid: 0.04, micHigh: 0.05) }
        #expect(first.seedHash == second.seedHash)

        let analyzer = SceneFingerprintAnalyzer()
        analyzer.startListening(now: 0)
        for frame in 0..<240 {
            let time = Double(frame) / 60.0
            analyzer.push(sample: sample(time: time, micAmplitude: 0.2, micLow: 0.03, micMid: 0.04, micHigh: 0.05))
        }
        let captured = analyzer.captureFingerprint(now: 4)
        analyzer.push(sample: sample(time: 4.1, accelX: 0.9, micAmplitude: 1.0, micLow: 0.9, micMid: 0.0, micHigh: 0.0))

        #expect(analyzer.candidateFingerprint?.seedHash == captured.seedHash)
    }

    @Test func freezeAmbientStopsLiveAndGeneratedStateChanges() {
        let analyzer = SceneFingerprintAnalyzer()
        analyzer.startListening(now: 0)
        for frame in 0..<240 {
            analyzer.push(sample: sample(time: Double(frame) / 60.0, micAmplitude: 0.2, micLow: 0.04, micMid: 0.04, micHigh: 0.04))
        }
        _ = analyzer.captureFingerprint(now: 4)
        analyzer.freezeAmbient()
        let live = analyzer.currentLiveFields
        let state = analyzer.generatedState

        analyzer.push(sample: sample(time: 4.2, accelX: 0.95, micAmplitude: 1.0, micLow: 0.0, micMid: 0.0, micHigh: 1.0))

        #expect(analyzer.currentLiveFields == live)
        #expect(analyzer.generatedState == state)
    }

    @Test func zeroAmbientInfluenceStopsLiveGeneratedStateChanges() {
        let analyzer = SceneFingerprintAnalyzer()
        analyzer.startListening(now: 0)
        for frame in 0..<240 {
            analyzer.push(sample: sample(time: Double(frame) / 60.0,
                                         micAmplitude: 0.2,
                                         micLow: 0.04,
                                         micMid: 0.04,
                                         micHigh: 0.04))
        }
        _ = analyzer.captureFingerprint(now: 4)
        analyzer.ambientInfluence = 0
        let state = analyzer.generatedState

        analyzer.push(sample: sample(time: 4.2,
                                     accelX: 0.95,
                                     micAmplitude: 1.0,
                                     micLow: 0.0,
                                     micMid: 0.0,
                                     micHigh: 1.0))

        #expect(analyzer.generatedState == state)
    }

    @Test func microphoneDeniedStillCapturesMotionOnlyFingerprint() {
        let fingerprint = captureWindow { time in
            sample(time: time,
                   accelX: 0.52,
                   micAmplitude: 1.0,
                   micLow: 1.0,
                   micMid: 0.0,
                   micHigh: 0.0,
                   microphonePermissionGranted: false,
                   micSpectrumAvailable: false)
        }

        #expect(fingerprint.stableSeedFields.sourceMask.motionAvailable)
        #expect(!fingerprint.stableSeedFields.sourceMask.microphonePermissionGranted)
        #expect(fingerprint.stableSeedFields.roomEnergyMean == 0)
        #expect(fingerprint.stableSeedFields.spectralBrightnessMean == 0)
    }

    private func captureWindow(_ makeSample: (Double) -> SceneSensorSample) -> SceneFingerprint {
        let analyzer = SceneFingerprintAnalyzer()
        analyzer.startListening(now: 0)
        for frame in 0..<240 {
            let time = Double(frame) / 60.0
            analyzer.push(sample: makeSample(time))
        }
        return analyzer.captureFingerprint(now: 4)
    }

    private func sample(time: Double,
                        accelX: Double = 0.5,
                        accelY: Double = 0.5,
                        accelZ: Double = 0.5,
                        gyroX: Double = 0.5,
                        gyroY: Double = 0.5,
                        gyroZ: Double = 0.5,
                        micAmplitude: Double = 0,
                        micLow: Double = 0,
                        micMid: Double = 0,
                        micHigh: Double = 0,
                        microphonePermissionGranted: Bool = true,
                        micSpectrumAvailable: Bool = true) -> SceneSensorSample {
        SceneSensorSample(
            timestamp: time,
            accelX: accelX,
            accelY: accelY,
            accelZ: accelZ,
            gyroX: gyroX,
            gyroY: gyroY,
            gyroZ: gyroZ,
            micAmplitude: micAmplitude,
            micLow: micLow,
            micMid: micMid,
            micHigh: micHigh,
            motionAvailable: true,
            microphonePermissionGranted: microphonePermissionGranted,
            micSpectrumAvailable: micSpectrumAvailable
        )
    }
}
