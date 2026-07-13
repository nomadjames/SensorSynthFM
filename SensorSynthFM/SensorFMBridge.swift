// SensorFMBridge.swift
// SensorSynthFM
//
// Session 3 — Sensor-to-FM routing layer.
//
// Sits between SensorManager (sensor data source) and FMEngine (audio sink).
// Observes SensorManager's @Observable published values on the main thread,
// applies per-mapping IIR smoothing, scales to FM parameter ranges, and
// writes to FMEngine properties via AudioKit's AUParameter-backed setters
// (which are audio-thread safe by design).
//
// Audio thread safety contract:
//   - All sensor reads happen on the main thread via a 60 Hz Timer.
//   - No allocation, no locking, no blocking occurs in the audio path.
//   - FMEngine property writes go through AUParameter (safe from any thread).
//   - IIR state variables (smoothedXxx) are owned and mutated only on the
//     main thread — never touched from the audio callback.
//
// Mappings for Session 3 MVP:
//   1. Accelerometer magnitude  → modulationIndex  (tilt = timbre)
//   2. Mic amplitude            → amplitude        (room noise = loudness)
//   3. Gyroscope Y              → modulatorRatio   (rotate = harmonic shift)

import Foundation
import Combine

// MARK: - SensorFMBridge

@Observable
final class SensorFMBridge {

    // MARK: - Mapping enable toggles (UI-bindable)

    /// When true, accelerometer magnitude drives modulationIndex.
    var accelToModIndexEnabled: Bool = true

    /// When true, mic amplitude drives the FM engine amplitude.
    var micToAmplitudeEnabled: Bool = true

    /// When true, gyroscope Y drives modulatorRatio.
    var gyroYToModRatioEnabled: Bool = true

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

    // MARK: - Mapped output values (read-only, UI-observable)

    /// Smoothed accelerometer magnitude in 0–1 (pre-scale).
    private(set) var smoothedAccelMag: Double = 0.0

    /// Smoothed mic amplitude in 0–1.
    private(set) var smoothedMicAmp: Double = 0.0

    /// Smoothed gyroscope Y in 0–1.
    private(set) var smoothedGyroY: Double = 0.0

    /// Currently mapped modulationIndex value (0–10).
    private(set) var mappedModIndex: Double = 0.0

    /// Currently mapped amplitude value (0–1).
    private(set) var mappedAmplitude: Double = 0.0

    /// Currently mapped modulatorRatio value (0.1–20.0).
    private(set) var mappedModRatio: Double = 1.0

    // MARK: - Mapping ranges

    /// Output range for accelerometer → modulationIndex.
    /// sensor_mapping.md: 0–4 is the sweet spot ("table tap creates FM bite").
    var modIndexRange: ClosedRange<Double> = 0.0...4.0

    /// Output range for mic → amplitude.
    /// Full 0–1 range; min keeps a quiet floor so silence doesn't cut off.
    var amplitudeRange: ClosedRange<Double> = 0.1...0.85

    /// Output range for gyroY → modulatorRatio.
    /// fm_engine.md: 0.5–8 is musically useful for sensor modulation.
    var modRatioRange: ClosedRange<Double> = 0.5...8.0

    // MARK: - Dependencies (injected)

    private weak var sensorManager: SensorManager?
    private weak var fmEngine: FMEngine?

    // MARK: - Timer (main-thread polling at 60 Hz)

    private var updateTimer: Timer?

    // MARK: - Lifecycle

    /// Attach sensor and engine references and begin polling.
    func start(sensors: SensorManager, engine: FMEngine) {
        self.sensorManager = sensors
        self.fmEngine = engine
        scheduleTimer()
    }

    /// Detach and stop all polling.
    func stop() {
        updateTimer?.invalidate()
        updateTimer = nil
        sensorManager = nil
        fmEngine = nil
    }

    deinit { stop() }

    // MARK: - Timer scheduling

    private func scheduleTimer() {
        updateTimer?.invalidate()
        // 60 Hz poll — matches CoreMotion update rate and SensorManager's
        // own display timer, so no extra latency is introduced.
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 60.0,
            repeats: true
        ) { [weak self] _ in
            self?.tick()
        }
    }

    // MARK: - Per-frame update (main thread only, 60 Hz)

    private func tick() {
        guard let sensors = sensorManager, let engine = fmEngine else { return }

        // --- 1. Accelerometer magnitude → modulationIndex ---
        // Compute vector magnitude from the three normalised accel axes.
        // SensorManager normalises each axis to 0–1 (resting ≈ 0.5 per axis
        // for gravity). We compute the deviation from the resting centroid
        // (0.5, 0.5, 0.5) so that a motionless iPad yields magnitude ≈ 0.
        let ax = sensors.accelX - 0.5
        let ay = sensors.accelY - 0.5
        let az = sensors.accelZ - 0.5
        let rawAccelMag = min(sqrt(ax*ax + ay*ay + az*az) * 1.41, 1.0)
        // Factor of 1.41 (≈ sqrt(2)) maps a single-axis ±0.5 swing to full 0–1.

        smoothedAccelMag = iir(old: smoothedAccelMag,
                               new: rawAccelMag,
                               alpha: accelSmoothingAlpha)

        mappedModIndex = scale(smoothedAccelMag, to: modIndexRange)
        if accelToModIndexEnabled {
            engine.modulationIndex = mappedModIndex
        }

        // --- 2. Mic amplitude → amplitude ---
        let rawMic = sensors.micAmplitude
        smoothedMicAmp = iir(old: smoothedMicAmp,
                             new: rawMic,
                             alpha: micSmoothingAlpha)

        mappedAmplitude = scale(smoothedMicAmp, to: amplitudeRange)
        if micToAmplitudeEnabled {
            engine.amplitude = mappedAmplitude
        }

        // --- 3. Gyroscope Y → modulatorRatio ---
        // SensorManager normalises gyroY to 0–1 (rest ≈ 0.5).
        let rawGyroY = sensors.gyroY
        smoothedGyroY = iir(old: smoothedGyroY,
                            new: rawGyroY,
                            alpha: gyroSmoothingAlpha)

        mappedModRatio = scale(smoothedGyroY, to: modRatioRange)
        if gyroYToModRatioEnabled {
            engine.modulatorRatio = mappedModRatio
        }
    }

    // MARK: - DSP helpers (pure, allocation-free)

    /// One-pole IIR low-pass filter: y[n] = y[n-1] + alpha * (x[n] - y[n-1]).
    /// alpha=1.0 → pass-through (no smoothing); alpha→0 → very slow following.
    @inline(__always)
    private func iir(old: Double, new: Double, alpha: Double) -> Double {
        old + alpha * (new - old)
    }

    /// Map a normalised 0–1 value into an arbitrary output range.
    @inline(__always)
    private func scale(_ value: Double, to range: ClosedRange<Double>) -> Double {
        let clamped = min(max(value, 0.0), 1.0)
        return range.lowerBound + clamped * (range.upperBound - range.lowerBound)
    }
}
