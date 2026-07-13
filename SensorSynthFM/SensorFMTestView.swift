// SensorFMTestView.swift
// SensorSynthFM
//
// Session 3 — Combined sensor readout + FM control test screen.
//
// Layout (landscape, dark theme):
//   Left column  — sensor live values and their mapped FM outputs, per-mapping toggles
//   Center divider
//   Right column — FM engine sliders (reuses FMParameterSlider from FMTestView)
//                  + play/stop button
//
// Wiring:
//   SensorManager  → SensorFMBridge → FMEngine
//   SensorManager also drives the live readout labels directly (main thread, safe).
//
// To use this screen: swap SensorFMTestView() into SensorSynthFMApp.swift in
// place of FMTestView(), or wire it to a tab/navigation stack later.

import Foundation
import SwiftUI

// MARK: - SensorFMTestView

struct SensorFMTestView: View {

    // MARK: State objects

    @State private var engine = FMEngine()
    @State private var sensors = SensorManager()
    @State private var bridge = SensorFMBridge()

    // MARK: Body

    var body: some View {
        HStack(spacing: 0) {

            // ─── Left column: sensor readouts + toggles ────────────────────
            VStack(spacing: 0) {
                sectionHeader("SENSOR → FM ROUTING")

                ScrollView {
                    VStack(spacing: 20) {

                        // Mapping 1: Accelerometer → Mod Index
                        MappingCard(
                            sensorLabel: "ACCEL MAGNITUDE",
                            sensorValue: bridge.smoothedAccelMag,
                            arrowLabel: "→  MOD INDEX",
                            mappedValue: normalised(bridge.mappedModIndex, in: bridge.modIndexRange),
                            mappedUnit: String(format: "%.2f", bridge.mappedModIndex),
                            isEnabled: $bridge.accelToModIndexEnabled,
                            accentColor: SynthColors.accent,
                            sensorBar: {
                                SensorBar(value: bridge.smoothedAccelMag,
                                          color: SynthColors.accent)
                            }
                        )

                        SynthColors.divider.opacity(0.4).frame(height: 0.5)

                        // Mapping 2: Mic Amplitude → Amplitude
                        MappingCard(
                            sensorLabel: "MIC AMPLITUDE",
                            sensorValue: bridge.smoothedMicAmp,
                            arrowLabel: "→  AMPLITUDE",
                            mappedValue: normalised(bridge.mappedAmplitude, in: bridge.amplitudeRange),
                            mappedUnit: String(format: "%d%%", Int(bridge.mappedAmplitude * 100)),
                            isEnabled: $bridge.micToAmplitudeEnabled,
                            accentColor: SynthColors.sensorGreen,
                            sensorBar: {
                                SensorBar(value: bridge.smoothedMicAmp,
                                          color: SynthColors.sensorGreen)
                            }
                        )

                        micDebugPanel

                        SynthColors.divider.opacity(0.4).frame(height: 0.5)

                        // Mapping 3: Gyroscope Y → Modulator Ratio
                        MappingCard(
                            sensorLabel: "GYRO Y",
                            sensorValue: bridge.smoothedGyroY,
                            arrowLabel: "→  MOD RATIO",
                            mappedValue: normalised(bridge.mappedModRatio, in: bridge.modRatioRange),
                            mappedUnit: String(format: "%.2f:1", bridge.mappedModRatio),
                            isEnabled: $bridge.gyroYToModRatioEnabled,
                            accentColor: SynthColors.accentBlue,
                            sensorBar: {
                                SensorBar(value: bridge.smoothedGyroY,
                                          color: SynthColors.accentBlue)
                            }
                        )

                        SynthColors.divider.opacity(0.4).frame(height: 0.5)

                        // Raw sensor values panel
                        rawSensorPanel
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .frame(maxWidth: .infinity)
            .background(SynthColors.surface)

            SynthColors.divider.frame(width: 1)

            // ─── Right column: FM controls ─────────────────────────────────
            VStack(spacing: 0) {
                sectionHeader("FM ENGINE")

                // Play/stop row
                HStack(spacing: 16) {
                    // Status dot
                    HStack(spacing: 6) {
                        Circle()
                            .fill(engine.isPlaying ? SynthColors.sensorGreen
                                                   : SynthColors.surfaceRaised)
                            .frame(width: 8, height: 8)
                        Text(engine.isPlaying ? "PLAYING" : "STOPPED")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(engine.isPlaying ? SynthColors.sensorGreen
                                                              : SynthColors.textSecondary)
                    }
                    Spacer()
                    Button {
                        engine.isPlaying ? engine.noteOff() : engine.noteOn()
                    } label: {
                        Text(engine.isPlaying ? "STOP" : "PLAY")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(SynthColors.background)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(engine.isPlaying ? Color.red.opacity(0.8)
                                                         : SynthColors.accent)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                SynthColors.divider.frame(height: 1)

                ScrollView {
                    VStack(spacing: 20) {

                        // Carrier Frequency — manual only (no sensor mapping here)
                        FMParameterSlider(
                            label: "CARRIER FREQ",
                            value: $engine.carrierFrequency,
                            range: 20...2000,
                            step: 1,
                            displayValue: "\(Int(engine.carrierFrequency)) Hz",
                            color: SynthColors.accent,
                            description: "MANUAL ONLY — no sensor mapping"
                        )

                        SynthColors.divider.opacity(0.4).frame(height: 0.5)

                        // Modulator Ratio — sensor-driven when gyro mapping active
                        VStack(alignment: .leading, spacing: 4) {
                            FMParameterSlider(
                                label: "MOD RATIO",
                                value: $engine.modulatorRatio,
                                range: 0.1...20.0,
                                step: 0.1,
                                displayValue: String(format: "%.1f:1", engine.modulatorRatio),
                                color: SynthColors.accentBlue,
                                description: bridge.gyroYToModRatioEnabled
                                    ? "SENSOR DRIVEN BY GYRO Y — switch mapping OFF for manual"
                                    : "MANUAL — Gyro Y mapping OFF"
                            )
                            .disabled(bridge.gyroYToModRatioEnabled)
                            .opacity(bridge.gyroYToModRatioEnabled ? 0.55 : 1.0)
                            if bridge.gyroYToModRatioEnabled {
                                sensorDrivenBadge
                            }
                        }

                        SynthColors.divider.opacity(0.4).frame(height: 0.5)

                        // Modulation Index — sensor-driven when accel mapping active
                        VStack(alignment: .leading, spacing: 4) {
                            FMParameterSlider(
                                label: "MOD INDEX",
                                value: $engine.modulationIndex,
                                range: 0...10,
                                step: 0.1,
                                displayValue: String(format: "%.1f", engine.modulationIndex),
                                color: SynthColors.accent,
                                description: bridge.accelToModIndexEnabled
                                    ? "SENSOR DRIVEN BY ACCEL — switch mapping OFF for manual"
                                    : "MANUAL — Accel mapping OFF"
                            )
                            .disabled(bridge.accelToModIndexEnabled)
                            .opacity(bridge.accelToModIndexEnabled ? 0.55 : 1.0)
                            if bridge.accelToModIndexEnabled {
                                sensorDrivenBadge
                            }
                        }

                        SynthColors.divider.opacity(0.4).frame(height: 0.5)

                        // Amplitude — sensor-driven when mic mapping active
                        VStack(alignment: .leading, spacing: 4) {
                            FMParameterSlider(
                                label: "AMPLITUDE",
                                value: $engine.amplitude,
                                range: 0...1,
                                step: 0.01,
                                displayValue: String(format: "%d%%", Int(engine.amplitude * 100)),
                                color: SynthColors.sensorGreen,
                                description: bridge.micToAmplitudeEnabled
                                    ? "SENSOR DRIVEN BY MIC — switch mapping OFF for manual"
                                    : "MANUAL — Mic mapping OFF"
                            )
                            .disabled(bridge.micToAmplitudeEnabled)
                            .opacity(bridge.micToAmplitudeEnabled ? 0.55 : 1.0)
                            if bridge.micToAmplitudeEnabled {
                                sensorDrivenBadge
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .frame(maxWidth: .infinity)
            .background(SynthColors.background)
        }
        .background(SynthColors.background.ignoresSafeArea())
        .safeAreaPadding(.top, 8)
        .preferredColorScheme(.dark)
        .onAppear {
            sensors.start()
            engine.start(allowMicrophoneInput: true)
            bridge.start(sensors: sensors, engine: engine)
        }
        .onDisappear {
            bridge.stop()
            sensors.stop()
            engine.stop()
        }
    }

    // MARK: - Raw sensor panel

    private var rawSensorPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RAW SENSOR VALUES")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(SynthColors.textSecondary)

            Group {
                rawRow("ACCEL X", value: sensors.accelX)
                rawRow("ACCEL Y", value: sensors.accelY)
                rawRow("ACCEL Z", value: sensors.accelZ)
                rawRow("GYRO  X", value: sensors.gyroX)
                rawRow("GYRO  Y", value: sensors.gyroY)
                rawRow("GYRO  Z", value: sensors.gyroZ)
                rawRow("MIC RAW", value: sensors.micRawAmplitude)
                rawRow("MIC LVL", value: sensors.micAmplitude)
                rawRow("MIC LOW", value: sensors.micLow)
                rawRow("MIC MID", value: sensors.micMid)
                rawRow("MIC HI ", value: sensors.micHigh)
            }
        }
        .padding(10)
        .background(SynthColors.surfaceRaised)
        .cornerRadius(8)
    }

    private var micDebugPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MIC INPUT DEBUG")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(SynthColors.textSecondary)

            debugTextRow("PERMISSION", sensors.microphonePermissionStatus.uppercased())
            debugTextRow("MIC ENGINE", sensors.micDebugStatus.uppercased())
            rawRow("RAW RMS", value: sensors.micRawAmplitude)
            rawRow("POST GAIN", value: sensors.micAmplitude)
            rawRow("NOISE FLR", value: sensors.micNoiseFloor)
            rawRow("PEAK HOLD", value: sensors.micPeakHold)
            debugTextRow("TAP FRAMES", String(format: "%.0f", sensors.micLastFrameCount))
            debugTextRow("SESSION", "\(sensors.audioSessionCategory) / \(sensors.audioSessionMode)")
            debugTextRow("START", "SENSORS → FM INPUT")
            debugTextRow("INPUT", sensors.audioSessionInputRoute.isEmpty ? "none" : sensors.audioSessionInputRoute)
            debugTextRow("OUTPUT", sensors.audioSessionOutputRoute.isEmpty ? "none" : sensors.audioSessionOutputRoute)
            debugTextRow("DEST AMP", "\(Int(bridge.mappedAmplitude * 100))% " + (bridge.micToAmplitudeEnabled ? "ROUTED" : "OFF"))
        }
        .padding(10)
        .background(SynthColors.surfaceRaised)
        .cornerRadius(8)
    }

    private func rawRow(_ label: String, value: Double) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(SynthColors.textSecondary)
                .frame(width: 70, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(SynthColors.background)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(SynthColors.divider)
                        .frame(width: geo.size.width * min(max(value, 0), 1), height: 6)
                }
            }
            .frame(height: 6)
            Text(String(format: "%.3f", value))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(SynthColors.textPrimary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private func debugTextRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(SynthColors.textSecondary)
                .frame(width: 76, alignment: .leading)
            Text(value)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(SynthColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Reusable sub-views

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(SynthColors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(SynthColors.surfaceRaised)
        .overlay(
            SynthColors.divider.frame(height: 1),
            alignment: .bottom
        )
    }

    private func normalised(_ value: Double, in range: ClosedRange<Double>) -> Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private var sensorDrivenBadge: some View {
        Text("SENSOR DRIVEN")
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(SynthColors.sensorGreen)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(SynthColors.sensorGreen.opacity(0.15))
            .cornerRadius(3)
    }
}

// MARK: - MappingCard

/// Displays one sensor-to-FM mapping with live bar, values, and enable toggle.
private struct MappingCard<BarContent: View>: View {

    let sensorLabel: String
    let sensorValue: Double       // 0–1, drives the sensor side display
    let arrowLabel: String
    let mappedValue: Double       // 0–1 normalised for the destination bar
    let mappedUnit: String        // human-readable destination value
    @Binding var isEnabled: Bool
    let accentColor: Color
    @ViewBuilder let sensorBar: () -> BarContent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header row: sensor name + toggle
            HStack {
                Text(sensorLabel)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(isEnabled ? SynthColors.textPrimary
                                               : SynthColors.textSecondary)
                Spacer()
                Toggle("", isOn: $isEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: accentColor))
                    .labelsHidden()
                    .scaleEffect(0.8)
            }

            // Sensor bar + numeric. Stays live even when mapping is off.
            HStack(spacing: 8) {
                Text("IN")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(SynthColors.textSecondary)
                    .frame(width: 14)
                sensorBar()
                Text(String(format: "%.3f", sensorValue))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(SynthColors.textPrimary)
                    .frame(width: 44, alignment: .trailing)
            }

            // Arrow label
            HStack {
                Text(arrowLabel)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(accentColor)
            }

            // Destination bar + value. "MAP" means preview only, not audio authority.
            HStack(spacing: 8) {
                Text(isEnabled ? "OUT" : "MAP")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(SynthColors.textSecondary)
                    .frame(width: 14)
                SensorBar(value: mappedValue, color: accentColor.opacity(0.6))
                Text(mappedUnit)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(accentColor)
                    .frame(width: 44, alignment: .trailing)
            }

            Text(isEnabled ? "SENSOR DRIVES ENGINE" : "MAPPING OFF · SLIDER MANUAL")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(isEnabled ? accentColor : SynthColors.textSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SynthColors.surfaceRaised)
                .opacity(isEnabled ? 1.0 : 0.5)
        )
        .animation(.easeInOut(duration: 0.15), value: isEnabled)
    }
}

// MARK: - SensorBar

/// A simple horizontal bar that fills proportionally to `value` (0–1).
private struct SensorBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(SynthColors.background)
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: geo.size.width * min(max(value, 0), 1), height: 8)
                    .animation(.linear(duration: 1.0 / 60.0), value: value)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Preview

#Preview(traits: .landscapeLeft) {
    SensorFMTestView()
}
