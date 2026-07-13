// SceneFingerprint.swift
// SensorSynthFM
//
// Derived room/surface descriptors used as a preset seed and slow ambient layer.
// Raw sensor streams stay out of the audio path.

import Foundation

struct SceneVector3: Equatable {
    var x: Double
    var y: Double
    var z: Double

    static let zero = SceneVector3(x: 0, y: 0, z: 0)
    static let normalizedRest = SceneVector3(x: 0.5, y: 0.5, z: 0.5)
}

struct SceneSourceMask: Equatable {
    var motionAvailable: Bool
    var microphonePermissionGranted: Bool
    var micSpectrumAvailable: Bool
}

struct SceneSensorSample: Equatable {
    var timestamp: TimeInterval
    var accel: SceneVector3
    var gyro: SceneVector3
    var micAmplitude: Double
    var micBands: SceneVector3
    var sourceMask: SceneSourceMask

    init(timestamp: TimeInterval,
         accelX: Double, accelY: Double, accelZ: Double,
         gyroX: Double, gyroY: Double, gyroZ: Double,
         micAmplitude: Double = 0,
         micLow: Double = 0, micMid: Double = 0, micHigh: Double = 0,
         motionAvailable: Bool = true,
         microphonePermissionGranted: Bool = true,
         micSpectrumAvailable: Bool = true) {
        self.timestamp = timestamp
        self.accel = SceneVector3(x: accelX, y: accelY, z: accelZ)
        self.gyro = SceneVector3(x: gyroX, y: gyroY, z: gyroZ)
        self.micAmplitude = micAmplitude
        self.micBands = SceneVector3(x: micLow, y: micMid, z: micHigh)
        self.sourceMask = SceneSourceMask(
            motionAvailable: motionAvailable,
            microphonePermissionGranted: microphonePermissionGranted,
            micSpectrumAvailable: micSpectrumAvailable
        )
    }
}

struct SceneLiveFields: Equatable {
    var surfaceImpactEnvelope: Double = 0
    var surfaceVibrationEnvelope: Double = 0
    var roomEnergyEnvelope: Double = 0
    var spectralBrightnessEnvelope: Double = 0
    var bassPressureEnvelope: Double = 0
    var deviceStillnessEnvelope: Double = 1
    var orientationDriftEnvelope: Double = 0
}

struct SceneStableSeedFields: Equatable {
    var captureDurationSeconds: Double
    var sourceMask: SceneSourceMask
    var restingAccelMean: SceneVector3
    var gyroBiasMean: SceneVector3
    var surfaceVibrationMean: Double
    var surfaceVibrationP90: Double
    var impactP95: Double
    var noiseFloorP10: Double
    var roomEnergyMean: Double
    var roomEnergyP90: Double
    var spectralProfileMean: SceneVector3
    var spectralBrightnessMean: Double
    var bassPressureMean: Double
    var deviceStillnessMean: Double
    var orientationDriftMean: Double
    var seedHash: UInt64
}

struct SceneFingerprint: Equatable {
    static let currentVersion = 1

    var version: Int = SceneFingerprint.currentVersion
    var capturedAt: TimeInterval
    var stableSeedFields: SceneStableSeedFields
    var liveFields: SceneLiveFields
    var mutationCounter: Int = 0

    var seedHash: UInt64 { stableSeedFields.seedHash }
}

struct SceneMusicalState: Equatable {
    var carrierFrequency: Double = 220
    var modulatorRatio: Double = 1
    var modulationIndex: Double = 1
    var amplitude: Double = 0.45

    var brightnessBias: Double = 0
    var densityBias: Double = 0
    var weightBias: Double = 0
    var modulationDepthBias: Double = 0
    var instabilityBias: Double = 0
    var settleBias: Double = 1
    var mutationAmount: Double = 0
}
