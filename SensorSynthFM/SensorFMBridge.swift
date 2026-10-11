// SensorFMBridge.swift
// SensorSynthFM
//
// Main/control-thread sensor-to-FM modulation matrix. The audio render thread is
// untouched; all writes still go through FMEngine's AudioKit parameter setters.

import Foundation
import Observation

protocol SensorFMParameterSink: AnyObject {
    func apply(output: SensorModulationOutput, preserveTouchPitch: Bool)
    func setFilter(mode: FilterMode, bypassed: Bool)
}

@Observable
final class SensorFMBridge {

    // MARK: - Matrix

    var matrix = SensorModulationMatrix.testStartingPatch()

    /// Performance mode keeps touch pitch authoritative and exposes only a
    /// bounded, labeled timbral underlay. Matrix mode preserves full routing.
    var performanceMode = false {
        didSet { recalculateAndApply() }
    }
    private(set) var performanceTimbreAmount: Double = 0.0
    private(set) var filterMode: FilterMode = .lowPass
    private(set) var filterBypassed = true

    func setFilter(mode: FilterMode, bypassed: Bool) {
        filterMode = mode
        filterBypassed = bypassed
        parameterSink?.setFilter(mode: mode, bypassed: bypassed)
    }

    // MARK: - Smoothing coefficients (configurable, 0 = frozen, 1 = raw/instant)

    /// IIR coefficient for the accelerometer magnitude smoother.
    /// Lower = more lag (smoother). Range 0.0–1.0. Default 0.08 (~5 Hz at 60 fps).
    var accelSmoothingAlpha: Double = 0.08

    /// IIR coefficient for the mic amplitude smoother.
    /// Default 0.12 (~8 Hz at 60 fps).
    var micSmoothingAlpha: Double = 0.12

    /// IIR coefficient for the gyroscope Y smoother.
    /// Default 0.06 (~4 Hz at 60 fps).
    var gyroSmoothingAlpha: Double = 0.06

    // MARK: - Source and output state (UI-observable)

    private(set) var smoothedAccelMag: Double = 0.0
    private(set) var smoothedMicAmp: Double = 0.0
    private(set) var smoothedGyroY: Double = 0.5
    private(set) var sourceValues = SensorModulationSourceValues()
    private(set) var output = SensorModulationMatrix.testStartingPatch().evaluate(sources: SensorModulationSourceValues())

    // MARK: - Dependencies (injected)

    private weak var sensorManager: SensorManager?
    private weak var parameterSink: SensorFMParameterSink?
    private weak var sceneAnalyzer: SceneFingerprintAnalyzer?

    init(parameterSink: SensorFMParameterSink? = nil) {
        self.parameterSink = parameterSink
    }

    /// Attach parameter controls independently of sensors/live audio (also used by UI tests).
    func attach(engine: FMEngine) {
        parameterSink = engine
        engine.setFilter(mode: filterMode, bypassed: filterBypassed)
        recalculateAndApply()
    }

    private var updateTimer: Timer?

    // MARK: - Lifecycle

    /// Attach sensor and engine references and begin polling.
    func start(sensors: SensorManager, engine: FMEngine, sceneAnalyzer: SceneFingerprintAnalyzer? = nil) {
        self.sensorManager = sensors
        self.parameterSink = engine
        self.sceneAnalyzer = sceneAnalyzer
        engine.setFilter(mode: filterMode, bypassed: filterBypassed)
        recalculateAndApply()
        scheduleTimer()
    }

    /// Detach and stop all polling.
    func stop() {
        updateTimer?.invalidate()
        updateTimer = nil
        sensorManager = nil
        parameterSink = nil
        sceneAnalyzer = nil
    }

    deinit { stop() }

    // MARK: - Matrix editing

    func resetToStart() {
        matrix = SensorModulationMatrix.testStartingPatch()
        setFilter(mode: .lowPass, bypassed: true)
        recalculateAndApply()
    }

    func amount(source: SensorModulationSource, target: SensorModulationTarget) -> Double {
        matrix.amount(source: source, target: target)
    }

    func setAmount(_ value: Double, source: SensorModulationSource, target: SensorModulationTarget) {
        matrix.setAmount(value, source: source, target: target)
        recalculateAndApply()
    }

    func stepAmount(source: SensorModulationSource, target: SensorModulationTarget, by delta: Double) {
        setAmount(amount(source: source, target: target) + delta, source: source, target: target)
    }

    func baseValue(for target: SensorModulationTarget) -> Double {
        matrix.baseValue(for: target)
    }

    func setBaseValue(_ value: Double, for target: SensorModulationTarget) {
        matrix.setBaseValue(value, for: target)
        recalculateAndApply()
    }

    func applySceneBase(_ state: SceneMusicalState) {
        matrix.applyBase(from: state)
        recalculateAndApply()
    }

    func sourceValue(for source: SensorModulationSource) -> Double {
        sourceValues.value(for: source)
    }

    func outputValue(for target: SensorModulationTarget) -> Double {
        output.value(for: target)
    }

    func outputNormalisedValue(for target: SensorModulationTarget) -> Double {
        output.normalisedValue(for: target)
    }

    func outputIsClamped(_ target: SensorModulationTarget) -> Bool {
        output.isClamped(target)
    }

    // MARK: - Timer scheduling

    private func scheduleTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 60.0,
            repeats: true
        ) { [weak self] _ in
            self?.tick()
        }
    }

    // MARK: - Per-frame update (main thread only, 60 Hz)

    private func tick() {
        guard let sensors = sensorManager else { return }

        let ax = sensors.accelX - 0.5
        let ay = sensors.accelY - 0.5
        let az = sensors.accelZ - 0.5
        let rawAccelMag = min(sqrt(ax * ax + ay * ay + az * az) * 1.41, 1.0)

        smoothedAccelMag = iir(old: smoothedAccelMag,
                               new: rawAccelMag,
                               alpha: accelSmoothingAlpha)
        smoothedMicAmp = iir(old: smoothedMicAmp,
                             new: sensors.micAmplitude,
                             alpha: micSmoothingAlpha)
        smoothedGyroY = iir(old: smoothedGyroY,
                            new: sensors.gyroY,
                            alpha: gyroSmoothingAlpha)

        let live = sceneAnalyzer?.currentLiveFields
        sourceValues = SensorModulationSourceValues(
            accelMagnitude: smoothedAccelMag,
            micAmplitude: smoothedMicAmp,
            gyroY: smoothedGyroY,
            roomEnergy: live?.roomEnergyEnvelope ?? 0,
            spectralBrightness: live?.spectralBrightnessEnvelope ?? 0,
            bassPressure: live?.bassPressureEnvelope ?? 0,
            surfaceVibration: live?.surfaceVibrationEnvelope ?? 0,
            surfaceImpact: live?.surfaceImpactEnvelope ?? 0,
            deviceStillness: live?.deviceStillnessEnvelope ?? 1
        )

        recalculateAndApply()
    }

    private func recalculateAndApply() {
        output = matrix.evaluate(sources: sourceValues)
        performanceTimbreAmount = min(
            1.0,
            abs(output.modulatorRatio - matrix.baseValue(for: .modulatorRatio)) / 20.0
                + abs(output.modulationIndex - matrix.baseValue(for: .modulationIndex)) / 10.0
                + abs(output.amplitude - matrix.baseValue(for: .amplitude))
        )
        guard let engine = parameterSink else { return }

        // One bounded parameter frame, not ten property-observer graph walks.
        // Performance and Instrument retain touch-owned pitch; Matrix retains full routing.
        engine.apply(output: output, preserveTouchPitch: performanceMode)
    }

    // MARK: - DSP helpers (pure, allocation-free)

    /// One-pole IIR low-pass filter: y[n] = y[n-1] + alpha * (x[n] - y[n-1]).
    @inline(__always)
    private func iir(old: Double, new: Double, alpha: Double) -> Double {
        guard new.isFinite else { return old }
        let boundedAlpha = alpha.isFinite ? min(max(alpha, 0), 1) : 0
        return old + boundedAlpha * (new - old)
    }
}
