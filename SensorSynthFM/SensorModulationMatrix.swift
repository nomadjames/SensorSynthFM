// SensorModulationMatrix.swift
// SensorSynthFM
//
// Small control-thread modulation matrix: source columns, target rows, bipolar cells.
// Audio render thread is not involved.

import Foundation

enum SensorModulationSource: Int, CaseIterable, Identifiable {
    case accelMagnitude
    case micAmplitude
    case gyroY
    case roomEnergy
    case spectralBrightness
    case bassPressure
    case surfaceVibration
    case surfaceImpact
    case deviceStillness

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .accelMagnitude: return "ACCEL MAG"
        case .micAmplitude: return "MIC AMP"
        case .gyroY: return "GYRO Y"
        case .roomEnergy: return "ROOM ENERGY"
        case .spectralBrightness: return "BRIGHTNESS"
        case .bassPressure: return "BASS PRESS"
        case .surfaceVibration: return "SURFACE VIBE"
        case .surfaceImpact: return "IMPACT"
        case .deviceStillness: return "STILLNESS"
        }
    }

    var isSceneDescriptor: Bool { rawValue >= SensorModulationSource.roomEnergy.rawValue }
}

enum SensorModulationTarget: Int, CaseIterable, Identifiable {
    case carrierFrequency
    case modulatorRatio
    case modulationIndex
    case amplitude

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .carrierFrequency: return "CARRIER FREQ"
        case .modulatorRatio: return "MOD RATIO"
        case .modulationIndex: return "MOD INDEX"
        case .amplitude: return "AMPLITUDE"
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .carrierFrequency: return 20...2000
        case .modulatorRatio: return 0.1...20
        case .modulationIndex: return 0...10
        case .amplitude: return 0...1
        }
    }

    var step: Double {
        switch self {
        case .carrierFrequency: return 1
        case .modulatorRatio: return 0.1
        case .modulationIndex: return 0.1
        case .amplitude: return 0.01
        }
    }

    var span: Double { range.upperBound - range.lowerBound }

    func normalised(_ value: Double) -> Double {
        guard span > 0 else { return 0 }
        return clamp01((clamp(value) - range.lowerBound) / span)
    }

    func denormalised(_ value: Double) -> Double {
        range.lowerBound + clamp01(value) * span
    }

    func clamp(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

struct SensorModulationSourceValues: Equatable {
    var accelMagnitude: Double = 0
    var micAmplitude: Double = 0
    var gyroY: Double = 0.5
    var roomEnergy: Double = 0
    var spectralBrightness: Double = 0
    var bassPressure: Double = 0
    var surfaceVibration: Double = 0
    var surfaceImpact: Double = 0
    var deviceStillness: Double = 1

    func value(for source: SensorModulationSource) -> Double {
        let raw: Double
        switch source {
        case .accelMagnitude: raw = accelMagnitude
        case .micAmplitude: raw = micAmplitude
        case .gyroY: raw = gyroY
        case .roomEnergy: raw = roomEnergy
        case .spectralBrightness: raw = spectralBrightness
        case .bassPressure: raw = bassPressure
        case .surfaceVibration: raw = surfaceVibration
        case .surfaceImpact: raw = surfaceImpact
        case .deviceStillness: raw = deviceStillness
        }
        return clamp01(raw)
    }

    func contribution(for source: SensorModulationSource) -> Double {
        let value = value(for: source)
        return source == .gyroY ? (value - 0.5) * 2.0 : value
    }
}

struct SensorModulationOutput: Equatable {
    var carrierFrequency: Double
    var modulatorRatio: Double
    var modulationIndex: Double
    var amplitude: Double

    var carrierFrequencyNorm: Double
    var modulatorRatioNorm: Double
    var modulationIndexNorm: Double
    var amplitudeNorm: Double

    var carrierFrequencyClamped: Bool
    var modulatorRatioClamped: Bool
    var modulationIndexClamped: Bool
    var amplitudeClamped: Bool

    func value(for target: SensorModulationTarget) -> Double {
        switch target {
        case .carrierFrequency: return carrierFrequency
        case .modulatorRatio: return modulatorRatio
        case .modulationIndex: return modulationIndex
        case .amplitude: return amplitude
        }
    }

    func normalisedValue(for target: SensorModulationTarget) -> Double {
        switch target {
        case .carrierFrequency: return carrierFrequencyNorm
        case .modulatorRatio: return modulatorRatioNorm
        case .modulationIndex: return modulationIndexNorm
        case .amplitude: return amplitudeNorm
        }
    }

    func isClamped(_ target: SensorModulationTarget) -> Bool {
        switch target {
        case .carrierFrequency: return carrierFrequencyClamped
        case .modulatorRatio: return modulatorRatioClamped
        case .modulationIndex: return modulationIndexClamped
        case .amplitude: return amplitudeClamped
        }
    }
}

struct SensorModulationMatrix: Equatable {
    private static let sourceCount = SensorModulationSource.allCases.count
    private static let amountCount = SensorModulationTarget.allCases.count * sourceCount

    private var amounts: [Double]
    private var baseCarrierFrequency: Double
    private var baseModulatorRatio: Double
    private var baseModulationIndex: Double
    private var baseAmplitude: Double

    init(seedDefaults: Bool = true) {
        amounts = Array(repeating: 0, count: Self.amountCount)
        baseCarrierFrequency = 440
        baseModulatorRatio = 4.25
        baseModulationIndex = 0
        baseAmplitude = 0.1

        guard seedDefaults else { return }
        setAmount(0.4, source: .accelMagnitude, target: .modulationIndex)
        setAmount(0.75, source: .micAmplitude, target: .amplitude)
        setAmount(3.75 / SensorModulationTarget.modulatorRatio.span, source: .gyroY, target: .modulatorRatio)
    }

    static func defaultMatrix() -> SensorModulationMatrix {
        SensorModulationMatrix()
    }

    func amount(source: SensorModulationSource, target: SensorModulationTarget) -> Double {
        amounts[index(source: source, target: target)]
    }

    mutating func setAmount(_ value: Double, source: SensorModulationSource, target: SensorModulationTarget) {
        amounts[index(source: source, target: target)] = min(max(value, -1), 1)
    }

    func baseValue(for target: SensorModulationTarget) -> Double {
        switch target {
        case .carrierFrequency: return baseCarrierFrequency
        case .modulatorRatio: return baseModulatorRatio
        case .modulationIndex: return baseModulationIndex
        case .amplitude: return baseAmplitude
        }
    }

    mutating func setBaseValue(_ value: Double, for target: SensorModulationTarget) {
        let clamped = target.clamp(value)
        switch target {
        case .carrierFrequency: baseCarrierFrequency = clamped
        case .modulatorRatio: baseModulatorRatio = clamped
        case .modulationIndex: baseModulationIndex = clamped
        case .amplitude: baseAmplitude = clamped
        }
    }

    mutating func applyBase(carrierFrequency: Double,
                            modulatorRatio: Double,
                            modulationIndex: Double,
                            amplitude: Double) {
        setBaseValue(carrierFrequency, for: .carrierFrequency)
        setBaseValue(modulatorRatio, for: .modulatorRatio)
        setBaseValue(modulationIndex, for: .modulationIndex)
        setBaseValue(amplitude, for: .amplitude)
    }

    mutating func applyBase(from state: SceneMusicalState) {
        applyBase(
            carrierFrequency: state.carrierFrequency,
            modulatorRatio: state.modulatorRatio,
            modulationIndex: state.modulationIndex,
            amplitude: state.amplitude
        )
    }

    func evaluate(sources: SensorModulationSourceValues) -> SensorModulationOutput {
        let carrier = evaluate(target: .carrierFrequency, sources: sources)
        let ratio = evaluate(target: .modulatorRatio, sources: sources)
        let index = evaluate(target: .modulationIndex, sources: sources)
        let amplitude = evaluate(target: .amplitude, sources: sources)

        return SensorModulationOutput(
            carrierFrequency: carrier.actual,
            modulatorRatio: ratio.actual,
            modulationIndex: index.actual,
            amplitude: amplitude.actual,
            carrierFrequencyNorm: carrier.normalised,
            modulatorRatioNorm: ratio.normalised,
            modulationIndexNorm: index.normalised,
            amplitudeNorm: amplitude.normalised,
            carrierFrequencyClamped: carrier.clamped,
            modulatorRatioClamped: ratio.clamped,
            modulationIndexClamped: index.clamped,
            amplitudeClamped: amplitude.clamped
        )
    }

    private func evaluate(target: SensorModulationTarget,
                          sources: SensorModulationSourceValues) -> (actual: Double, normalised: Double, clamped: Bool) {
        var rawNorm = target.normalised(baseValue(for: target))
        for source in SensorModulationSource.allCases {
            rawNorm += amount(source: source, target: target) * sources.contribution(for: source)
        }
        let clampedNorm = clamp01(rawNorm)
        return (target.denormalised(clampedNorm), clampedNorm, abs(clampedNorm - rawNorm) > 0.000_000_1)
    }

    private func index(source: SensorModulationSource, target: SensorModulationTarget) -> Int {
        target.rawValue * Self.sourceCount + source.rawValue
    }
}

private func clamp01(_ value: Double) -> Double {
    min(max(value, 0), 1)
}
