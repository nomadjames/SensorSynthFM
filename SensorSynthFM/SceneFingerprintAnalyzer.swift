// SceneFingerprintAnalyzer.swift
// SensorSynthFM
//
// Control-side descriptor extractor. It never runs on the audio render thread.

import Foundation

@Observable
final class SceneFingerprintAnalyzer {
    static let defaultListenDuration: TimeInterval = 4.0
    private static let listenLeadInSeconds: TimeInterval = 0.35

    var ambientInfluence: Double = 1.0 {
        didSet { updateGeneratedState() }
    }

    private(set) var currentLiveFields = SceneLiveFields()
    private(set) var candidateFingerprint: SceneFingerprint?
    private(set) var savedFingerprint: SceneFingerprint?
    private(set) var generatedState = SceneMusicalState()
    private(set) var isListening = false
    private(set) var isAmbientFrozen = false
    private(set) var listenProgress: Double = 0

    private let generator = SceneMusicalStateGenerator()
    private var listenDuration = SceneFingerprintAnalyzer.defaultListenDuration
    private var listenStartTime: TimeInterval?
    private var listenSamples: [SceneSensorSample] = []
    private var stableSeedFields: SceneStableSeedFields?
    private var frozenLiveFields = SceneLiveFields()
    private var mutationCounter = 0

    func startListening(duration: TimeInterval = SceneFingerprintAnalyzer.defaultListenDuration,
                        now: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        listenDuration = max(duration, 0.1)
        listenStartTime = now
        listenSamples.removeAll(keepingCapacity: true)
        listenProgress = 0
        mutationCounter = 0
        isListening = true
        isAmbientFrozen = false
    }

    func push(sample: SceneSensorSample) {
        if isListening {
            let start = listenStartTime ?? sample.timestamp
            listenStartTime = start
            let elapsed = max(sample.timestamp - start, 0)
            listenProgress = clamp01(elapsed / listenDuration)

            if elapsed >= Self.listenLeadInSeconds {
                listenSamples.append(sample)
            }

            if elapsed >= listenDuration {
                _ = captureFingerprint(now: sample.timestamp)
            }
        }

        updateLiveFields(with: sample)
    }

    @discardableResult
    func captureFingerprint(now: TimeInterval = Date().timeIntervalSinceReferenceDate) -> SceneFingerprint {
        var seed = makeStableSeedFields(from: listenSamples)
        seed.seedHash = stableSeedHash(seed)
        stableSeedFields = seed

        isListening = false
        listenProgress = 1

        let live = isAmbientFrozen ? frozenLiveFields : currentLiveFields
        let fingerprint = SceneFingerprint(
            capturedAt: now,
            stableSeedFields: seed,
            liveFields: live,
            mutationCounter: mutationCounter
        )
        candidateFingerprint = fingerprint
        updateGeneratedState()
        return fingerprint
    }

    func freezeAmbient() {
        frozenLiveFields = currentLiveFields
        isAmbientFrozen = true
        updateGeneratedState()
    }

    func unfreezeAmbient() {
        isAmbientFrozen = false
        updateGeneratedState()
    }

    @discardableResult
    func regenerate() -> SceneMusicalState {
        guard var fingerprint = candidateFingerprint else { return generatedState }
        mutationCounter += 1
        fingerprint.mutationCounter = mutationCounter
        candidateFingerprint = fingerprint
        updateGeneratedState()
        return generatedState
    }

    func saveCurrentScene() {
        // ponytail: proof-harness save only; add disk persistence with a real preset browser.
        savedFingerprint = candidateFingerprint
    }

    private func updateLiveFields(with sample: SceneSensorSample) {
        guard !isAmbientFrozen else { return }

        let restingAccel = stableSeedFields?.restingAccelMean ?? .normalizedRest
        let gyroBias = stableSeedFields?.gyroBiasMean ?? .normalizedRest
        let accelDeviation = sample.sourceMask.motionAvailable ? distance(sample.accel, restingAccel) * 2.0 : 0
        let gyroDeviation = sample.sourceMask.motionAvailable ? distance(sample.gyro, gyroBias) * 2.0 : 0
        let impactInput = clamp01(max(accelDeviation - 0.04, 0) * 3.0)
        let vibrationInput = clamp01((accelDeviation * 0.65 + gyroDeviation * 0.35) * 1.2)

        let micAllowed = sample.sourceMask.microphonePermissionGranted
        let spectrumAllowed = micAllowed && sample.sourceMask.micSpectrumAvailable
        let noiseFloor = stableSeedFields?.noiseFloorP10 ?? 0
        let roomInput = micAllowed ? clamp01(max(sample.micAmplitude - noiseFloor, 0) / max(1 - noiseFloor, 0.001)) : 0
        let ratios = spectralRatios(for: sample, allowed: spectrumAllowed)
        let driftInput = stableSeedFields == nil ? 0 : clamp01(accelDeviation * 0.5 + gyroDeviation * 0.5)

        var next = currentLiveFields
        next.surfaceImpactEnvelope = max(impactInput, currentLiveFields.surfaceImpactEnvelope * 0.85)
        next.surfaceVibrationEnvelope = onePole(currentLiveFields.surfaceVibrationEnvelope, vibrationInput, 0.08)
        next.roomEnergyEnvelope = envelope(currentLiveFields.roomEnergyEnvelope, roomInput, attack: 0.25, release: 0.08)
        next.spectralBrightnessEnvelope = onePole(currentLiveFields.spectralBrightnessEnvelope, ratios.brightness, 0.06)
        next.bassPressureEnvelope = onePole(currentLiveFields.bassPressureEnvelope, ratios.bass, 0.06)
        next.deviceStillnessEnvelope = onePole(currentLiveFields.deviceStillnessEnvelope, 1 - clamp01(vibrationInput * 0.75 + impactInput * 0.25), 0.04)
        next.orientationDriftEnvelope = onePole(currentLiveFields.orientationDriftEnvelope, driftInput, 0.02)
        currentLiveFields = next

        updateGeneratedState()
    }

    private func updateGeneratedState() {
        guard let fingerprint = candidateFingerprint else { return }
        let live = isAmbientFrozen ? frozenLiveFields : currentLiveFields
        generatedState = generator.generate(
            from: fingerprint,
            liveFields: live,
            ambientInfluence: ambientInfluence,
            mutation: mutationCounter
        )
    }

    private func makeStableSeedFields(from samples: [SceneSensorSample]) -> SceneStableSeedFields {
        let sourceMask = SceneSourceMask(
            motionAvailable: samples.contains { $0.sourceMask.motionAvailable },
            microphonePermissionGranted: samples.contains { $0.sourceMask.microphonePermissionGranted },
            micSpectrumAvailable: samples.contains { $0.sourceMask.microphonePermissionGranted && $0.sourceMask.micSpectrumAvailable }
        )
        let motionSamples = samples.filter { $0.sourceMask.motionAvailable }
        let micSamples = samples.filter { $0.sourceMask.microphonePermissionGranted }
        let spectrumSamples = samples.filter { $0.sourceMask.microphonePermissionGranted && $0.sourceMask.micSpectrumAvailable }

        let accelMean = meanVector(motionSamples.map(\.accel), fallback: .normalizedRest)
        let gyroMean = meanVector(motionSamples.map(\.gyro), fallback: .normalizedRest)
        let vibrationValues = motionSamples.map { sample in
            let accelDeviation = distance(sample.accel, accelMean) * 2.0
            let gyroDeviation = distance(sample.gyro, gyroMean) * 2.0
            return clamp01((accelDeviation * 0.65 + gyroDeviation * 0.35) * 1.2)
        }
        let impactValues = motionSamples.map { sample in
            clamp01(max(distance(sample.accel, accelMean) * 2.0 - 0.04, 0) * 3.0)
        }
        let micAmplitudes = micSamples.map { clamp01($0.micAmplitude) }
        let noiseFloor = percentile(micAmplitudes, 0.10)
        let roomValues = micAmplitudes.map { clamp01(max($0 - noiseFloor, 0) / max(1 - noiseFloor, 0.001)) }
        let ratioValues = spectrumSamples.map { spectralRatios(for: $0, allowed: true) }
        let lowMean = mean(ratioValues.map(\.low))
        let midMean = mean(ratioValues.map(\.mid))
        let highMean = mean(ratioValues.map(\.high))
        let stillnessValues = vibrationValues.enumerated().map { index, vibration in
            let impact = index < impactValues.count ? impactValues[index] : 0
            return 1 - clamp01(vibration * 0.75 + impact * 0.25)
        }

        return SceneStableSeedFields(
            captureDurationSeconds: listenDuration,
            sourceMask: sourceMask,
            restingAccelMean: accelMean,
            gyroBiasMean: gyroMean,
            surfaceVibrationMean: mean(vibrationValues),
            surfaceVibrationP90: percentile(vibrationValues, 0.90),
            impactP95: percentile(impactValues, 0.95),
            noiseFloorP10: noiseFloor,
            roomEnergyMean: mean(roomValues),
            roomEnergyP90: percentile(roomValues, 0.90),
            spectralProfileMean: SceneVector3(x: lowMean, y: midMean, z: highMean),
            spectralBrightnessMean: highMean,
            bassPressureMean: lowMean,
            deviceStillnessMean: stillnessValues.isEmpty ? 1 : mean(stillnessValues),
            orientationDriftMean: 0,
            seedHash: 0
        )
    }

    private func stableSeedHash(_ seed: SceneStableSeedFields) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603

        func mixByte(_ byte: UInt8) {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        func mixBucket(_ value: Double, maxValue: Double = 1) {
            let scaled = clamp(value / maxValue, 0, 1) * 255
            mixByte(UInt8(scaled.rounded()))
        }

        mixByte(UInt8(SceneFingerprint.currentVersion))
        mixBucket(seed.captureDurationSeconds, maxValue: 8)
        mixByte(seed.sourceMask.motionAvailable ? 1 : 0)
        mixByte(seed.sourceMask.microphonePermissionGranted ? 1 : 0)
        mixByte(seed.sourceMask.micSpectrumAvailable ? 1 : 0)
        [seed.restingAccelMean, seed.gyroBiasMean, seed.spectralProfileMean].forEach { vector in
            mixBucket(vector.x)
            mixBucket(vector.y)
            mixBucket(vector.z)
        }
        [
            seed.surfaceVibrationMean,
            seed.surfaceVibrationP90,
            seed.impactP95,
            seed.noiseFloorP10,
            seed.roomEnergyMean,
            seed.roomEnergyP90,
            seed.spectralBrightnessMean,
            seed.bassPressureMean,
            seed.deviceStillnessMean,
            seed.orientationDriftMean
        ].forEach { mixBucket($0) }

        return hash
    }

    private func spectralRatios(for sample: SceneSensorSample, allowed: Bool) -> (low: Double, mid: Double, high: Double, brightness: Double, bass: Double) {
        guard allowed else { return (0, 0, 0, 0, 0) }
        let low = clamp01(sample.micBands.x)
        let mid = clamp01(sample.micBands.y)
        let high = clamp01(sample.micBands.z)
        let total = low + mid + high
        guard total > 0.000_001 else { return (0, 0, 0, 0, 0) }
        return (low / total, mid / total, high / total, high / total, low / total)
    }

    private func meanVector(_ values: [SceneVector3], fallback: SceneVector3) -> SceneVector3 {
        guard !values.isEmpty else { return fallback }
        return SceneVector3(
            x: mean(values.map(\.x)),
            y: mean(values.map(\.y)),
            z: mean(values.map(\.z))
        )
    }

    private func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func percentile(_ values: [Double], _ percentile: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = Int((Double(sorted.count - 1) * clamp01(percentile)).rounded())
        return sorted[min(max(index, 0), sorted.count - 1)]
    }

    private func distance(_ lhs: SceneVector3, _ rhs: SceneVector3) -> Double {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        let dz = lhs.z - rhs.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }

    private func onePole(_ old: Double, _ new: Double, _ alpha: Double) -> Double {
        old + clamp01(alpha) * (new - old)
    }

    private func envelope(_ old: Double, _ new: Double, attack: Double, release: Double) -> Double {
        onePole(old, new, new > old ? attack : release)
    }

    private func clamp01(_ value: Double) -> Double {
        clamp(value, 0, 1)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
