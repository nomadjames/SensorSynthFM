// SensorFMTestView.swift
// SensorSynthFM
//
// Combined sensor readout + touch-first modulation matrix + FM base controls.

import Foundation
import SwiftUI

struct SensorFMTestView: View {

    @State private var engine = FMEngine()
    @State private var sensors = SensorManager()
    @State private var bridge = SensorFMBridge()
    @State private var sceneAnalyzer = SceneFingerprintAnalyzer()
    @State private var sceneTimer: Timer?

    @State private var selectedSource: SensorModulationSource = .accelMagnitude
    @State private var selectedTarget: SensorModulationTarget = .modulationIndex
    @State private var appliedSceneKey: String?
    @State private var regenFeedback = "GEN 0 · RATIO UNCHANGED"

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                sectionHeader("SCENE FINGERPRINT + MATRIX")

                ScrollView {
                    VStack(spacing: 16) {
                        sceneFingerprintPanel
                        modulationMatrixPanel
                        micDebugPanel
                        rawSensorPanel
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .frame(maxWidth: .infinity)
            .background(SynthColors.surface)

            SynthColors.divider.frame(width: 1)

            VStack(spacing: 0) {
                sectionHeader("FM ENGINE")
                playStopRow
                SynthColors.divider.frame(height: 1)
                fmBaseControls
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
            bridge.start(sensors: sensors, engine: engine, sceneAnalyzer: sceneAnalyzer)
            startSceneFingerprintUpdates()
        }
        .onDisappear {
            stopSceneFingerprintUpdates()
            bridge.stop()
            sensors.stop()
            engine.stop()
        }
    }

    // MARK: - Scene Fingerprint

    private var sceneFingerprintPanel: some View {
        let live = sceneAnalyzer.currentLiveFields
        let state = sceneAnalyzer.generatedState
        let seedHash = sceneAnalyzer.candidateFingerprint.map { String($0.seedHash, radix: 16, uppercase: true) } ?? "NO SEED"

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SCENE FINGERPRINT")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(SynthColors.textPrimary)
                Spacer()
                Text(sceneAnalyzer.isListening ? "LISTENING \(Int(sceneAnalyzer.listenProgress * 100))%" : seedHash)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(SynthColors.textSecondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                sceneButton("LISTEN 4S", disabled: sceneAnalyzer.isListening) {
                    appliedSceneKey = nil
                    sceneAnalyzer.startListening()
                }
                sceneButton(sceneAnalyzer.isAmbientFrozen ? "UNFREEZE" : "FREEZE", disabled: sceneAnalyzer.candidateFingerprint == nil) {
                    if sceneAnalyzer.isAmbientFrozen {
                        sceneAnalyzer.unfreezeAmbient()
                    } else {
                        sceneAnalyzer.freezeAmbient()
                    }
                }
                sceneButton("REGEN", disabled: sceneAnalyzer.candidateFingerprint == nil) {
                    regenerateSceneBase()
                }
                sceneButton("SAVE", disabled: sceneAnalyzer.candidateFingerprint == nil) {
                    sceneAnalyzer.saveCurrentScene()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("AMBIENT INFLUENCE")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(SynthColors.textSecondary)
                    Spacer()
                    Text("\(Int(sceneAnalyzer.ambientInfluence * 100))%")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(SynthColors.textPrimary)
                }
                Slider(value: $sceneAnalyzer.ambientInfluence, in: 0...1)
                    .tint(SynthColors.accent)
            }

            descriptorRow("ROOM ENERGY", value: live.roomEnergyEnvelope, color: SynthColors.sensorGreen)
            descriptorRow("BRIGHTNESS", value: live.spectralBrightnessEnvelope, color: SynthColors.accent)
            descriptorRow("BASS PRESSURE", value: live.bassPressureEnvelope, color: SynthColors.accentBlue)
            descriptorRow("SURFACE VIBE", value: live.surfaceVibrationEnvelope, color: SynthColors.divider)
            descriptorRow("SURFACE IMPACT", value: live.surfaceImpactEnvelope, color: SynthColors.accent)
            descriptorRow("DEVICE STILL", value: live.deviceStillnessEnvelope, color: SynthColors.sensorGreen)

            Text(String(format: "STATE  carrier %.0fHz  ratio %.1f  index %.2f  amp %d%%",
                        state.carrierFrequency,
                        state.modulatorRatio,
                        state.modulationIndex,
                        Int(state.amplitude * 100)))
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(SynthColors.textSecondary)

            if sceneAnalyzer.candidateFingerprint != nil {
                Text(regenFeedback)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(SynthColors.accent)
            }

            if sceneAnalyzer.savedFingerprint != nil {
                Text("SAVED (SESSION ONLY)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(SynthColors.sensorGreen)
            }

            Text("FREEZE HOLDS SCENE DESCRIPTORS; RAW SENSOR ROUTING REMAINS LIVE.")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(SynthColors.textSecondary)
        }
        .padding(12)
        .background(SynthColors.surfaceRaised)
        .cornerRadius(8)
    }

    private func startSceneFingerprintUpdates() {
        sceneTimer?.invalidate()
        sceneTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { _ in
            sceneAnalyzer.push(sample: SceneSensorSample(
                timestamp: Date().timeIntervalSinceReferenceDate,
                accelX: sensors.accelX,
                accelY: sensors.accelY,
                accelZ: sensors.accelZ,
                gyroX: sensors.gyroX,
                gyroY: sensors.gyroY,
                gyroZ: sensors.gyroZ,
                micAmplitude: sensors.micAmplitude,
                micLow: sensors.micLow,
                micMid: sensors.micMid,
                micHigh: sensors.micHigh,
                motionAvailable: true,
                microphonePermissionGranted: sensors.microphonePermissionGranted,
                micSpectrumAvailable: sensors.micSpectrumAvailable
            ))
            applySceneBaseIfNeeded()
        }
    }

    private func stopSceneFingerprintUpdates() {
        sceneTimer?.invalidate()
        sceneTimer = nil
    }

    private func applySceneBaseIfNeeded() {
        guard let key = currentSceneKey(), key != appliedSceneKey else { return }
        let oldRatio = bridge.baseValue(for: .modulatorRatio)
        bridge.applySceneBase(sceneAnalyzer.generatedState)
        appliedSceneKey = key
        setRegenFeedback(oldRatio: oldRatio)
    }

    private func regenerateSceneBase() {
        let oldRatio = bridge.baseValue(for: .modulatorRatio)
        let state = sceneAnalyzer.regenerate()
        bridge.applySceneBase(state)
        appliedSceneKey = currentSceneKey()
        setRegenFeedback(oldRatio: oldRatio)
    }

    private func setRegenFeedback(oldRatio: Double) {
        let generation = sceneAnalyzer.candidateFingerprint?.mutationCounter ?? 0
        let changed = abs(oldRatio - sceneAnalyzer.generatedState.modulatorRatio) > 0.000_001
        regenFeedback = "GEN \(generation) · \(changed ? "RATIO CHANGED" : "RATIO UNCHANGED")"
    }

    private func currentSceneKey() -> String? {
        guard let fingerprint = sceneAnalyzer.candidateFingerprint else { return nil }
        return "\(fingerprint.seedHash)-\(fingerprint.mutationCounter)"
    }

    // MARK: - Modulation Matrix

    private var modulationMatrixPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MODULATION MATRIX")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(SynthColors.textPrimary)
                Spacer()
                Text("\(selectedSource.label) → \(selectedTarget.label)")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(SynthColors.textSecondary)
                    .lineLimit(1)
            }

            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    Text("TARGET")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(SynthColors.textSecondary)
                        .frame(width: 116, height: 68, alignment: .bottomLeading)
                    ForEach(SensorModulationTarget.allCases) { target in
                        targetLabel(target)
                    }
                }

                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(spacing: 0) {
                        HStack(spacing: 6) {
                            ForEach(SensorModulationSource.allCases) { source in
                                sourceHeader(source)
                            }
                        }
                        ForEach(SensorModulationTarget.allCases) { target in
                            HStack(spacing: 6) {
                                ForEach(SensorModulationSource.allCases) { source in
                                    matrixCell(source: source, target: target)
                                }
                            }
                        }
                    }
                    .padding(.leading, 6)
                }
            }

            selectedCellEditor
        }
        .padding(12)
        .background(SynthColors.surfaceRaised)
        .cornerRadius(8)
    }

    private func sourceHeader(_ source: SensorModulationSource) -> some View {
        let selected = source == selectedSource
        let hold = source.isSceneDescriptor && sceneAnalyzer.isAmbientFrozen
        let value = bridge.sourceValue(for: source)

        return VStack(alignment: .leading, spacing: 5) {
            Text(source.label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(selected ? SynthColors.accent : SynthColors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            SensorBar(value: value, color: color(for: source))
            HStack {
                Text(String(format: "%.2f", value))
                    .font(.system(size: 8, design: .monospaced))
                Spacer(minLength: 0)
                if hold {
                    Text("HOLD")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                }
            }
            .foregroundColor(hold ? SynthColors.accent : SynthColors.textSecondary)
        }
        .padding(6)
        .frame(width: 92, height: 68)
        .background(selected ? SynthColors.accent.opacity(0.15) : SynthColors.background.opacity(0.55))
        .cornerRadius(6)
    }

    private func targetLabel(_ target: SensorModulationTarget) -> some View {
        let selected = target == selectedTarget
        return VStack(alignment: .leading, spacing: 2) {
            Text(target.label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(selected ? SynthColors.accent : SynthColors.textPrimary)
            Text(format(target, bridge.outputValue(for: target)))
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(bridge.outputIsClamped(target) ? Color.red.opacity(0.9) : SynthColors.textSecondary)
        }
        .padding(.horizontal, 6)
        .frame(width: 116, height: 50, alignment: .leading)
        .background(selected ? SynthColors.accent.opacity(0.15) : Color.clear)
        .cornerRadius(6)
    }

    private func matrixCell(source: SensorModulationSource, target: SensorModulationTarget) -> some View {
        let selected = source == selectedSource && target == selectedTarget
        let amount = bridge.amount(source: source, target: target)
        let active = abs(amount) > 0.000_001
        let text = selected || active ? signedPercent(amount) : ""

        return Button {
            selectedSource = source
            selectedTarget = target
        } label: {
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(active || selected ? SynthColors.textPrimary : SynthColors.textSecondary)
                .frame(width: 92, height: 50)
                .background(cellColor(amount: amount, selected: selected))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selected ? SynthColors.accent : Color.clear, lineWidth: 2)
                )
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var selectedCellEditor: some View {
        let amount = bridge.amount(source: selectedSource, target: selectedTarget)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SELECTED CELL")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(SynthColors.textSecondary)
                Spacer()
                Text(signedPercent(amount))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(amount < 0 ? SynthColors.accentBlue : SynthColors.accent)
            }

            Slider(value: amountBinding(source: selectedSource, target: selectedTarget), in: -1...1, step: 0.01)
                .tint(amount < 0 ? SynthColors.accentBlue : SynthColors.accent)

            HStack(spacing: 10) {
                editorButton("−") { bridge.stepAmount(source: selectedSource, target: selectedTarget, by: -0.01) }
                editorButton("+") { bridge.stepAmount(source: selectedSource, target: selectedTarget, by: 0.01) }
                editorButton("ZERO") { bridge.setAmount(0, source: selectedSource, target: selectedTarget) }
            }
        }
        .padding(10)
        .background(SynthColors.background.opacity(0.55))
        .cornerRadius(8)
    }

    private func amountBinding(source: SensorModulationSource, target: SensorModulationTarget) -> Binding<Double> {
        Binding(
            get: { bridge.amount(source: source, target: target) },
            set: { bridge.setAmount($0, source: source, target: target) }
        )
    }

    private func editorButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(SynthColors.background)
                .frame(minWidth: title == "ZERO" ? 72 : 44, minHeight: 44)
                .background(SynthColors.accent)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - FM engine controls

    private var playStopRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle()
                    .fill(engine.isPlaying ? SynthColors.sensorGreen : SynthColors.surfaceRaised)
                    .frame(width: 8, height: 8)
                Text(engine.isPlaying ? "PLAYING" : "STOPPED")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(engine.isPlaying ? SynthColors.sensorGreen : SynthColors.textSecondary)
            }
            Spacer()
            Button {
                engine.isPlaying ? engine.noteOff() : engine.noteOn()
            } label: {
                Text(engine.isPlaying ? "STOP" : "PLAY")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(SynthColors.background)
                    .frame(minWidth: 92, minHeight: 44)
                    .background(engine.isPlaying ? Color.red.opacity(0.8) : SynthColors.accent)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var fmBaseControls: some View {
        ScrollView {
            VStack(spacing: 20) {
                baseSlider(.carrierFrequency, color: SynthColors.accent)
                SynthColors.divider.opacity(0.4).frame(height: 0.5)
                baseSlider(.modulatorRatio, color: SynthColors.accentBlue)
                SynthColors.divider.opacity(0.4).frame(height: 0.5)
                baseSlider(.modulationIndex, color: SynthColors.accent)
                SynthColors.divider.opacity(0.4).frame(height: 0.5)
                baseSlider(.amplitude, color: SynthColors.sensorGreen)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private func baseSlider(_ target: SensorModulationTarget, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FMParameterSlider(
                label: target.label,
                value: baseBinding(target),
                range: target.range,
                step: target.step,
                displayValue: format(target, bridge.baseValue(for: target)),
                color: color,
                description: "Slider edits BASE. Matrix writes LIVE output below."
            )
            HStack {
                Text("BASE \(format(target, bridge.baseValue(for: target)))")
                Spacer()
                Text("LIVE \(format(target, bridge.outputValue(for: target)))")
                if bridge.outputIsClamped(target) {
                    Text("CLAMPED")
                        .foregroundColor(Color.red.opacity(0.9))
                }
            }
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundColor(SynthColors.textSecondary)
        }
    }

    private func baseBinding(_ target: SensorModulationTarget) -> Binding<Double> {
        Binding(
            get: { bridge.baseValue(for: target) },
            set: { bridge.setBaseValue($0, for: target) }
        )
    }

    // MARK: - Raw sensor and debug panels

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
            debugTextRow("LIVE AMP", format(.amplitude, bridge.outputValue(for: .amplitude)))
        }
        .padding(10)
        .background(SynthColors.surfaceRaised)
        .cornerRadius(8)
    }

    // MARK: - Reusable UI helpers

    private func sceneButton(_ title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(disabled ? SynthColors.textSecondary : SynthColors.background)
                .frame(minWidth: 74, minHeight: 44)
                .background(disabled ? SynthColors.divider.opacity(0.25) : SynthColors.accent)
                .cornerRadius(7)
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }

    private func descriptorRow(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(SynthColors.textSecondary)
                .frame(width: 92, alignment: .leading)
            SensorBar(value: min(max(value, 0), 1), color: color)
            Text(String(format: "%.2f", value))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(SynthColors.textPrimary)
                .frame(width: 34, alignment: .trailing)
        }
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
        .overlay(SynthColors.divider.frame(height: 1), alignment: .bottom)
    }

    private func signedPercent(_ value: Double) -> String {
        if abs(value) < 0.000_001 { return "+0%" }
        return String(format: "%+.0f%%", value * 100)
    }

    private func format(_ target: SensorModulationTarget, _ value: Double) -> String {
        switch target {
        case .carrierFrequency: return "\(Int(value.rounded())) Hz"
        case .modulatorRatio: return String(format: "%.2f:1", value)
        case .modulationIndex: return String(format: "%.2f", value)
        case .amplitude: return "\(Int((value * 100).rounded()))%"
        }
    }

    private func color(for source: SensorModulationSource) -> Color {
        switch source {
        case .accelMagnitude, .spectralBrightness, .surfaceImpact: return SynthColors.accent
        case .micAmplitude, .roomEnergy, .deviceStillness: return SynthColors.sensorGreen
        case .gyroY, .bassPressure: return SynthColors.accentBlue
        case .surfaceVibration: return SynthColors.divider
        }
    }

    private func cellColor(amount: Double, selected: Bool) -> Color {
        if selected { return SynthColors.accent.opacity(0.25) }
        if amount > 0 { return SynthColors.accent.opacity(0.18) }
        if amount < 0 { return SynthColors.accentBlue.opacity(0.18) }
        return SynthColors.background.opacity(0.65)
    }
}

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

#Preview(traits: .landscapeLeft) {
    SensorFMTestView()
}
