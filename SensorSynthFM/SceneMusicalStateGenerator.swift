// SceneMusicalStateGenerator.swift
// SensorSynthFM
//
// Small deterministic mapper from a captured scene seed to current FM macro values.

import Foundation

struct SceneMusicalStateGenerator {
    private static let ratioFamilies: [Double] = [0.5, 1, 1.5, 2, 3, 4, 6, 8]

    func generate(from fingerprint: SceneFingerprint,
                  liveFields: SceneLiveFields? = nil,
                  ambientInfluence: Double = 1,
                  mutation: Int? = nil) -> SceneMusicalState {
        let seed = fingerprint.stableSeedFields
        let live = liveFields ?? fingerprint.liveFields
        let influence = clamp01(ambientInfluence)
        let mutationCounter = max(mutation ?? fingerprint.mutationCounter, 0)

        let mixedHash = fingerprint.seedHash &+ (UInt64(mutationCounter) &* 1_315_423_911)
        let seededRatio = Self.ratioFamilies[Int(mixedHash % UInt64(Self.ratioFamilies.count))]
        let ratio = seed.bassPressureMean > 0.65 ? min(seededRatio, 2) : seededRatio

        let brightness = clamp01(seed.spectralBrightnessMean * 0.7 + live.spectralBrightnessEnvelope * 0.3 * influence)
        let density = clamp01(seed.roomEnergyMean * 0.7 + live.roomEnergyEnvelope * 0.3 * influence)
        let weight = clamp01(seed.bassPressureMean * 0.75 + live.bassPressureEnvelope * 0.25 * influence)
        let instability = clamp01(seed.surfaceVibrationMean * 0.6 + live.surfaceVibrationEnvelope * 0.3 * influence + live.orientationDriftEnvelope * 0.1 * influence)
        let settle = clamp01(seed.deviceStillnessMean * 0.7 + live.deviceStillnessEnvelope * 0.3 * influence)
        let impactAccent = live.surfaceImpactEnvelope * influence

        return SceneMusicalState(
            carrierFrequency: 220,
            modulatorRatio: ratio,
            modulationIndex: clamp(0.8 + brightness * 3.2 + density * 2.0 + instability * 1.5 + impactAccent * 2.5 - settle * 0.4, 0, 10),
            amplitude: clamp(0.35 + density * 0.18 + weight * 0.08, 0.2, 0.65),
            brightnessBias: brightness,
            densityBias: density,
            weightBias: weight,
            modulationDepthBias: clamp01(brightness * 0.6 + density * 0.4 + impactAccent * 0.5),
            instabilityBias: instability,
            settleBias: settle,
            mutationAmount: Double(mutationCounter)
        )
    }

    private func clamp01(_ value: Double) -> Double {
        clamp(value, 0, 1)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
