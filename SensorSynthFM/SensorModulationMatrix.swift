// Control-thread catalog and bipolar sensor matrix. Stable IDs: append, never reorder.
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

/// Shared bounds, defaults, units and normalization used by UI, routes and DSP.
enum SensorModulationTarget: Int, CaseIterable, Identifiable {
    case carrierFrequency
    case modulatorRatio
    case modulationIndex
    case amplitude
    case ampAttack
    case ampDecay
    case ampSustain
    case ampRelease
    case filterCutoff
    case filterResonance

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .carrierFrequency: return "CARRIER FREQ"
        case .modulatorRatio: return "MOD RATIO"
        case .modulationIndex: return "MOD INDEX"
        case .amplitude: return "AMPLITUDE"
        case .ampAttack: return "AMP ATTACK"
        case .ampDecay: return "AMP DECAY"
        case .ampSustain: return "AMP SUSTAIN"
        case .ampRelease: return "AMP RELEASE"
        case .filterCutoff: return "FILTER CUTOFF"
        case .filterResonance: return "FILTER RES"
        }
    }
    var range: ClosedRange<Double> {
        switch self {
        case .carrierFrequency: return 20...2000
        case .modulatorRatio: return 0.1...20
        case .modulationIndex: return 0...10
        case .amplitude, .ampSustain, .filterResonance: return 0...1
        case .ampAttack, .ampDecay: return 0.005...5
        case .ampRelease: return 0.02...5
        case .filterCutoff: return 20...18_000
        }
    }
    var defaultValue: Double {
        switch self {
        case .carrierFrequency: return 440
        case .modulatorRatio: return 4.25
        case .modulationIndex: return 0
        case .amplitude: return 0.1
        case .ampAttack: return 0.005
        case .ampDecay: return 0.1
        case .ampSustain: return 1
        case .ampRelease: return 0.35
        case .filterCutoff: return 18_000
        case .filterResonance: return 0
        }
    }
    var step: Double {
        switch self {
        case .carrierFrequency, .filterCutoff: return 1
        case .modulatorRatio, .modulationIndex: return 0.1
        case .amplitude, .ampSustain, .filterResonance: return 0.01
        case .ampAttack, .ampDecay, .ampRelease: return 0.005
        }
    }
    var span: Double { range.upperBound - range.lowerBound }
    func normalised(_ value: Double) -> Double {
        let bounded = clamp(value)
        if self == .filterCutoff {
            return clamp01(log(bounded / range.lowerBound) / log(range.upperBound / range.lowerBound))
        }
        return clamp01((bounded - range.lowerBound) / span)
    }
    func denormalised(_ value: Double) -> Double {
        if self == .filterCutoff {
            return range.lowerBound * pow(range.upperBound / range.lowerBound, clamp01(value))
        }
        return range.lowerBound + clamp01(value) * span
    }
    func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return defaultValue }
        return min(max(value, range.lowerBound), range.upperBound)
    }
    func formatted(_ value: Double) -> String {
        let value = clamp(value)
        switch self {
        case .carrierFrequency, .filterCutoff: return String(format: "%.0f Hz", value)
        case .modulatorRatio: return String(format: "%.2f:1", value)
        case .modulationIndex: return String(format: "%.2f", value)
        case .amplitude, .ampSustain, .filterResonance: return String(format: "%.0f%%", value * 100)
        case .ampAttack, .ampDecay, .ampRelease: return String(format: "%.0f ms", value * 1000)
        }
    }
}

enum FilterMode: String, CaseIterable, Identifiable {
    case lowPass = "LP"
    case highPass = "HP"
    case bandPass = "BP"
    var id: String { rawValue }

    /// Native LP/HP resonance is dB; cap at +6 instead of exposing Apple's +40.
    static func resonanceDecibels(_ amount: Double) -> Double { clamp01(amount) * 6 }
    /// Native BP bandwidth is cents: narrower at higher normalized resonance.
    static func bandwidthCents(_ amount: Double) -> Double { 2400 - clamp01(amount) * 2100 }
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
        // Invalid bipolar source is neutral, not its negative extreme.
        return raw.isFinite ? clamp01(raw) : (source == .gyroY ? 0.5 : 0)
    }
    func contribution(for source: SensorModulationSource) -> Double {
        let value = value(for: source)
        return source == .gyroY ? (value - 0.5) * 2.0 : value
    }
}

struct SensorModulationOutput: Equatable {
    struct Resolved: Equatable {
        let actual: Double
        let normalised: Double
        let clamped: Bool
    }
    let values: [Resolved] // indexed by the stable catalog ID
    var carrierFrequency: Double { value(for: .carrierFrequency) }
    var modulatorRatio: Double { value(for: .modulatorRatio) }
    var modulationIndex: Double { value(for: .modulationIndex) }
    var amplitude: Double { value(for: .amplitude) }
    func value(for target: SensorModulationTarget) -> Double { values[target.rawValue].actual }
    func normalisedValue(for target: SensorModulationTarget) -> Double { values[target.rawValue].normalised }
    func isClamped(_ target: SensorModulationTarget) -> Bool { values[target.rawValue].clamped }
}

struct SensorModulationMatrix: Equatable {
    private static let sourceCount = SensorModulationSource.allCases.count
    private static let amountCount = SensorModulationTarget.allCases.count * sourceCount
    private var amounts: [Double]
    private var baseValues: [Double]

    init(seedDefaults: Bool = true) {
        amounts = Array(repeating: 0, count: Self.amountCount)
        baseValues = SensorModulationTarget.allCases.map(\.defaultValue)
        guard seedDefaults else { return }
        setAmount(0.4, source: .accelMagnitude, target: .modulationIndex)
        setAmount(0.75, source: .micAmplitude, target: .amplitude)
        setAmount(3.75 / SensorModulationTarget.modulatorRatio.span, source: .gyroY, target: .modulatorRatio)
    }
    static func defaultMatrix() -> SensorModulationMatrix { SensorModulationMatrix() }
    func amount(source: SensorModulationSource, target: SensorModulationTarget) -> Double {
        amounts[index(source: source, target: target)]
    }
    mutating func setAmount(_ value: Double, source: SensorModulationSource, target: SensorModulationTarget) {
        amounts[index(source: source, target: target)] = value.isFinite ? min(max(value, -1), 1) : 0
    }
    func baseValue(for target: SensorModulationTarget) -> Double { baseValues[target.rawValue] }
    mutating func setBaseValue(_ value: Double, for target: SensorModulationTarget) {
        baseValues[target.rawValue] = target.clamp(value)
    }
    mutating func applyBase(carrierFrequency: Double, modulatorRatio: Double, modulationIndex: Double, amplitude: Double) {
        setBaseValue(carrierFrequency, for: .carrierFrequency)
        setBaseValue(modulatorRatio, for: .modulatorRatio)
        setBaseValue(modulationIndex, for: .modulationIndex)
        setBaseValue(amplitude, for: .amplitude)
    }
    /// Scene generation owns only the accepted four FM bases, not envelopes/filter.
    mutating func applyBase(from state: SceneMusicalState) {
        applyBase(carrierFrequency: state.carrierFrequency, modulatorRatio: state.modulatorRatio,
                  modulationIndex: state.modulationIndex, amplitude: state.amplitude)
    }
    func evaluate(sources: SensorModulationSourceValues) -> SensorModulationOutput {
        SensorModulationOutput(values: SensorModulationTarget.allCases.map { target in
            var rawNorm = target.normalised(baseValue(for: target))
            for source in SensorModulationSource.allCases {
                rawNorm += amount(source: source, target: target) * sources.contribution(for: source)
            }
            let bounded = clamp01(rawNorm)
            return SensorModulationOutput.Resolved(actual: target.denormalised(bounded), normalised: bounded,
                                                   clamped: abs(bounded - rawNorm) > 0.000_000_1)
        })
    }
    private func index(source: SensorModulationSource, target: SensorModulationTarget) -> Int {
        target.rawValue * Self.sourceCount + source.rawValue
    }
}

private func clamp01(_ value: Double) -> Double {
    value.isFinite ? min(max(value, 0), 1) : 0
}
