// SensorManager.swift
// SensorSynthFM
//
// Pure data-layer class — no UI code.
// Reads CoreMotion (accelerometer + gyroscope at 60 Hz) and
// AVAudioEngine microphone input (RMS amplitude + 3-band FFT).
// All published values are normalised to 0.0–1.0.

import Foundation
import CoreMotion
import AVFoundation
import Accelerate

// MARK: - SensorManager

@Observable
final class SensorManager {

    // MARK: Motion (0.0–1.0, low-pass filtered)

    private(set) var accelX: Double = 0.0
    private(set) var accelY: Double = 0.0
    private(set) var accelZ: Double = 0.0

    private(set) var gyroX: Double = 0.0
    private(set) var gyroY: Double = 0.0
    private(set) var gyroZ: Double = 0.0

    // MARK: Microphone (0.0–1.0)

    private(set) var micRawAmplitude: Double = 0.0
    private(set) var micAmplitude: Double = 0.0
    private(set) var micNoiseFloor: Double = 0.0
    private(set) var micPeakHold: Double = 0.0
    private(set) var micLastFrameCount: Double = 0.0
    private(set) var micLow: Double = 0.0
    private(set) var micMid: Double = 0.0
    private(set) var micHigh: Double = 0.0

    private(set) var microphonePermissionGranted: Bool = false
    private(set) var microphonePermissionStatus: String = "not checked"
    private(set) var micSpectrumAvailable: Bool = false
    private(set) var micDebugStatus: String = "idle"
    private(set) var audioSessionCategory: String = "not set"
    private(set) var audioSessionMode: String = "not set"
    private(set) var audioSessionInputRoute: String = "none"
    private(set) var audioSessionOutputRoute: String = "none"

    // MARK: - Private state

    private let motionManager = CMMotionManager()
    private let audioEngine = AVAudioEngine()

    /// Low-pass smoothing factor for motion values (0 = no change, 1 = raw).
    private let motionSmoothing: Double = 0.1

    /// Maximum expected magnitude for normalisation.
    /// Accelerometer ±4 g, gyroscope ±8 rad/s are reasonable dynamic ranges.
    private let accelScale: Double = 4.0
    private let gyroScale: Double = 8.0

    /// Envelope timing converted to 60 Hz display-timer coefficients.
    private var attackCoeff: Float = 0.0
    private var releaseCoeff: Float = 0.0
    private let micGain: Double = 12.0
    private let micPeakDecay: Double = 0.96
    private let displayInterval: TimeInterval = 1.0 / 60.0

    /// Pre-allocated FFT scratch buffers (set once in start, never re-allocated).
    private var fftRealBuffer: UnsafeMutablePointer<Float>?
    private var fftImagBuffer: UnsafeMutablePointer<Float>?
    private var fftLength: Int = 0
    private var fftSetup: FFTSetup?

    /// Atomics written from the audio thread, read on main.
    /// Using UnsafeMutablePointer<Float> for lock-free, allocation-free updates.
    private var atomicRMS: UnsafeMutablePointer<Float>?
    private var atomicLow: UnsafeMutablePointer<Float>?
    private var atomicMid: UnsafeMutablePointer<Float>?
    private var atomicHigh: UnsafeMutablePointer<Float>?
    private var atomicTapFrames: UnsafeMutablePointer<Float>?

    /// Display-link timer to pull values off the audio thread.
    private var displayTimer: Timer?
    private var inputTapInstalled = false

    /// Envelope state (main-thread only, raw input before gain/noise-floor).
    private var envelopeRMS: Double = 0.0
    private var envelopeLow: Double = 0.0
    private var envelopeMid: Double = 0.0
    private var envelopeHigh: Double = 0.0

    // MARK: - Lifecycle

    func start() {
        startMotion()
        micDebugStatus = "checking permission"
        requestMicrophonePermission { [weak self] granted, status in
            DispatchQueue.main.async {
                self?.microphonePermissionGranted = granted
                self?.microphonePermissionStatus = status
                guard granted else {
                    self?.micDebugStatus = "permission \(status)"
                    return
                }
                self?.startAudio()
            }
        }
    }

    func stop() {
        stopMotion()
        stopAudio()
    }

    deinit {
        stop()
        freeAtomicBuffers()
    }

    // MARK: - Motion -------------------------------------------------------

    private func startMotion() {
        guard motionManager.isAccelerometerAvailable,
              motionManager.isGyroAvailable else { return }

        let interval: TimeInterval = 1.0 / 60.0
        motionManager.accelerometerUpdateInterval = interval
        motionManager.gyroUpdateInterval = interval

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let d = data else { return }
            self.applyAccelerometer(d.acceleration)
        }

        motionManager.startGyroUpdates(to: .main) { [weak self] data, _ in
            guard let self, let d = data else { return }
            self.applyGyroscope(d.rotationRate)
        }
    }

    private func stopMotion() {
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
    }

    private func applyAccelerometer(_ a: CMAcceleration) {
        accelX = lowPass(old: accelX, new: normalise(a.x, scale: accelScale))
        accelY = lowPass(old: accelY, new: normalise(a.y, scale: accelScale))
        accelZ = lowPass(old: accelZ, new: normalise(a.z, scale: accelScale))
    }

    private func applyGyroscope(_ r: CMRotationRate) {
        gyroX = lowPass(old: gyroX, new: normalise(r.x, scale: gyroScale))
        gyroY = lowPass(old: gyroY, new: normalise(r.y, scale: gyroScale))
        gyroZ = lowPass(old: gyroZ, new: normalise(r.z, scale: gyroScale))
    }

    /// Map a signed value into 0…1 using `scale` as the expected ± range.
    @inline(__always)
    private func normalise(_ value: Double, scale: Double) -> Double {
        let mapped = (value / scale + 1.0) / 2.0
        return min(max(mapped, 0.0), 1.0)
    }

    /// Simple IIR low-pass filter.
    @inline(__always)
    private func lowPass(old: Double, new: Double) -> Double {
        old + motionSmoothing * (new - old)
    }

    // MARK: - Microphone ---------------------------------------------------

    private func requestMicrophonePermission(completion: @escaping (Bool, String) -> Void) {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            completion(true, "granted")
        case .denied:
            completion(false, "denied")
        case .undetermined:
            microphonePermissionStatus = "asking"
            AVAudioApplication.requestRecordPermission { granted in
                completion(granted, granted ? "granted" : "denied")
            }
        @unknown default:
            completion(false, "unknown")
        }
    }

    private func startAudio() {
        guard !audioEngine.isRunning else { return }

        let session = AVAudioSession.sharedInstance()
        micDebugStatus = "configuring session"
        do {
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            updateAudioSessionDebug(session)
        } catch {
            micSpectrumAvailable = false
            micDebugStatus = "session error: \(error.localizedDescription)"
            return
        }

        guard session.isInputAvailable else {
            micSpectrumAvailable = false
            micDebugStatus = "no audio input route"
            return
        }

        let inputNode = audioEngine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)
        let sampleRate = Float(hwFormat.sampleRate)
        let bufferSize: AVAudioFrameCount = 512

        // --- Envelope coefficients ---
        // These are applied by the 60 Hz display timer, not per audio sample.
        let attackTime: Float = 0.030   // 30 ms
        let releaseTime: Float = 0.150  // 150 ms
        let timerStep = Float(displayInterval)
        attackCoeff  = 1.0 - expf(-timerStep / attackTime)
        releaseCoeff = 1.0 - expf(-timerStep / releaseTime)

        // --- Allocate atomic float pointers (once) ---
        allocateAtomicBuffers()

        // --- Pre-allocate FFT resources ---
        let log2n = vDSP_Length(log2f(Float(bufferSize)))
        fftLength = Int(bufferSize)

        // allocate real/imag scratch
        fftRealBuffer = .allocate(capacity: fftLength / 2)
        fftImagBuffer = .allocate(capacity: fftLength / 2)
        fftRealBuffer!.initialize(repeating: 0, count: fftLength / 2)
        fftImagBuffer!.initialize(repeating: 0, count: fftLength / 2)

        // --- Capture local copies for the closure (no self capture) ---
        let realBuf  = fftRealBuffer!
        let imagBuf  = fftImagBuffer!
        let halfLen  = fftLength / 2
        let aRMS     = atomicRMS!
        let aLow     = atomicLow!
        let aMid     = atomicMid!
        let aHigh    = atomicHigh!
        let aTapFrames = atomicTapFrames!
        let sr       = sampleRate

        // Bin boundaries for frequency bands.
        let binResolution = sr / Float(bufferSize)
        let lowEnd   = Int(300.0  / binResolution)  // 0–300 Hz
        let midEnd   = Int(2000.0 / binResolution)  // 300–2000 Hz
        // highEnd = halfLen                          // 2000 Hz+

        // FFT setup (Accelerate) — stored so it can be freed in freeFFTBuffers()
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        let fftSetupRef = fftSetup

        // --- Install tap (real-time safe closure) ---
        inputNode.installTap(onBus: 0, bufferSize: bufferSize,
                             format: hwFormat) { buffer, _ in
            guard let channelData = buffer.floatChannelData else { return }
            let frames = Int(buffer.frameLength)
            aTapFrames.pointee = Float(frames)
            let samples = channelData[0]  // mono channel 0

            // 1. RMS amplitude
            var rms: Float = 0.0
            vDSP_rmsqv(samples, 1, &rms, vDSP_Length(frames))

            // Clamp to 0…1 (RMS of a full-scale sine ≈ 0.707).
            let normRMS = min(rms / 0.707, 1.0)
            aRMS.pointee = normRMS

            // 2. FFT — in-place, no allocations.
            //    Copy samples into split complex (real part).
            guard let setup = fftSetupRef else { return }

            // Fill real buffer with windowed samples (rectangular — no window
            // multiply to stay allocation-free and lock-free).
            let count = min(frames, halfLen * 2)
            // Pack into split complex: even → real, odd → imag
            for i in 0 ..< halfLen {
                let idx = i * 2
                if idx < count {
                    realBuf[i] = samples[idx]
                } else {
                    realBuf[i] = 0
                }
                if idx + 1 < count {
                    imagBuf[i] = samples[idx + 1]
                } else {
                    imagBuf[i] = 0
                }
            }

            var splitComplex = DSPSplitComplex(realp: realBuf, imagp: imagBuf)
            vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

            // 3. Energy per band
            var lowEnergy: Float  = 0.0
            var midEnergy: Float  = 0.0
            var highEnergy: Float = 0.0

            for i in 0 ..< halfLen {
                let mag = realBuf[i] * realBuf[i] + imagBuf[i] * imagBuf[i]
                if i < lowEnd {
                    lowEnergy += mag
                } else if i < midEnd {
                    midEnergy += mag
                } else {
                    highEnergy += mag
                }
            }

            // Normalise by number of bins in each band to get mean energy,
            // then take sqrt for magnitude-scale, and clamp.
            let norm = { (energy: Float, binCount: Int) -> Float in
                guard binCount > 0 else { return 0 }
                let avg = energy / Float(binCount)
                let mag = sqrtf(avg) / Float(halfLen)
                return min(mag, 1.0)
            }

            aLow.pointee  = norm(lowEnergy,  max(lowEnd, 1))
            aMid.pointee  = norm(midEnergy,  max(midEnd - lowEnd, 1))
            aHigh.pointee = norm(highEnergy, max(halfLen - midEnd, 1))
        }
        inputTapInstalled = true

        // --- Start engine ---
        do {
            try audioEngine.start()
        } catch {
            micSpectrumAvailable = false
            micDebugStatus = "engine error: \(error.localizedDescription)"
            inputNode.removeTap(onBus: 0)
            inputTapInstalled = false
            return
        }

        micSpectrumAvailable = true
        micDebugStatus = "tap running"

        // --- Timer to pull atomic values to main thread ---
        let atk = Double(attackCoeff)
        let rel = Double(releaseCoeff)

        displayTimer = Timer.scheduledTimer(withTimeInterval: displayInterval,
                                            repeats: true) { [weak self] _ in
            guard let self else { return }
            let rawRMS  = Double(self.atomicRMS?.pointee ?? 0)
            let rawLow  = Double(self.atomicLow?.pointee ?? 0)
            let rawMid  = Double(self.atomicMid?.pointee ?? 0)
            let rawHigh = Double(self.atomicHigh?.pointee ?? 0)
            let tapFrames = Double(self.atomicTapFrames?.pointee ?? 0)

            self.envelopeRMS  = Self.envelope(old: self.envelopeRMS,  new: rawRMS,
                                              attack: atk, release: rel)
            self.envelopeLow  = Self.envelope(old: self.envelopeLow,  new: rawLow,
                                              attack: atk, release: rel)
            self.envelopeMid  = Self.envelope(old: self.envelopeMid,  new: rawMid,
                                              attack: atk, release: rel)
            self.envelopeHigh = Self.envelope(old: self.envelopeHigh, new: rawHigh,
                                              attack: atk, release: rel)

            self.micRawAmplitude = rawRMS
            self.micLastFrameCount = tapFrames
            self.micNoiseFloor = Self.noiseFloor(old: self.micNoiseFloor,
                                                 new: self.envelopeRMS)
            self.micAmplitude = min(max((self.envelopeRMS - self.micNoiseFloor) * self.micGain, 0), 1)
            self.micPeakHold = max(self.micAmplitude, self.micPeakHold * self.micPeakDecay)
            self.micLow       = self.envelopeLow
            self.micMid       = self.envelopeMid
            self.micHigh      = self.envelopeHigh
        }
    }

    private func stopAudio() {
        displayTimer?.invalidate()
        displayTimer = nil

        if inputTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            inputTapInstalled = false
        }
        audioEngine.stop()

        micSpectrumAvailable = false
        micDebugStatus = "stopped"
        micRawAmplitude = 0
        micAmplitude = 0
        micNoiseFloor = 0
        micLastFrameCount = 0
        micPeakHold = 0
        micLow = 0
        micMid = 0
        micHigh = 0

        freeFFTBuffers()

        envelopeRMS  = 0
        envelopeLow  = 0
        envelopeMid  = 0
        envelopeHigh = 0
    }

    private func updateAudioSessionDebug(_ session: AVAudioSession) {
        audioSessionCategory = session.category.rawValue
        audioSessionMode = session.mode.rawValue
        audioSessionInputRoute = session.currentRoute.inputs.map(\.portName).joined(separator: ", ")
        audioSessionOutputRoute = session.currentRoute.outputs.map(\.portName).joined(separator: ", ")
    }

    // MARK: - Envelope helper

    /// Attack/release envelope follower.
    @inline(__always)
    private static func envelope(old: Double, new: Double,
                                 attack: Double, release: Double) -> Double {
        let coeff = new > old ? attack : release
        return old + coeff * (new - old)
    }

    @inline(__always)
    private static func noiseFloor(old: Double, new: Double) -> Double {
        guard old > 0 else { return new }
        let alpha = new < old ? 0.20 : 0.001
        return old + alpha * (new - old)
    }

    // MARK: - Atomic buffer management

    private func allocateAtomicBuffers() {
        if atomicRMS == nil { atomicRMS = .allocate(capacity: 1); atomicRMS!.initialize(to: 0) } else { atomicRMS!.pointee = 0 }
        if atomicLow == nil { atomicLow = .allocate(capacity: 1); atomicLow!.initialize(to: 0) } else { atomicLow!.pointee = 0 }
        if atomicMid == nil { atomicMid = .allocate(capacity: 1); atomicMid!.initialize(to: 0) } else { atomicMid!.pointee = 0 }
        if atomicHigh == nil { atomicHigh = .allocate(capacity: 1); atomicHigh!.initialize(to: 0) } else { atomicHigh!.pointee = 0 }
        if atomicTapFrames == nil { atomicTapFrames = .allocate(capacity: 1); atomicTapFrames!.initialize(to: 0) } else { atomicTapFrames!.pointee = 0 }
    }

    private func freeAtomicBuffers() {
        atomicRMS?.deinitialize(count: 1);  atomicRMS?.deallocate();  atomicRMS  = nil
        atomicLow?.deinitialize(count: 1);  atomicLow?.deallocate();  atomicLow  = nil
        atomicMid?.deinitialize(count: 1);  atomicMid?.deallocate();  atomicMid  = nil
        atomicHigh?.deinitialize(count: 1); atomicHigh?.deallocate(); atomicHigh = nil
        atomicTapFrames?.deinitialize(count: 1); atomicTapFrames?.deallocate(); atomicTapFrames = nil
    }

    private func freeFFTBuffers() {
        let half = fftLength / 2
        fftRealBuffer?.deinitialize(count: half); fftRealBuffer?.deallocate(); fftRealBuffer = nil
        fftImagBuffer?.deinitialize(count: half); fftImagBuffer?.deallocate(); fftImagBuffer = nil
        if let setup = fftSetup { vDSP_destroy_fftsetup(setup); fftSetup = nil }
    }
}
