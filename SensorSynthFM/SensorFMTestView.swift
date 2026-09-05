// SensorFMTestView.swift
// SensorSynthFM
//
// Combined sensor readout + touch-first modulation matrix + FM base controls.

import Foundation
import SwiftUI

enum ModulationAmountInteraction {
    static let zeroSnapThreshold = 0.02

    static func dragAmount(_ value: Double) -> Double {
        let clamped = clamped(value)
        return abs(clamped) <= zeroSnapThreshold ? 0 : clamped
    }

    static func nudgeAmount(_ value: Double, by delta: Double) -> Double {
        clamped(value + delta)
    }

    static func formattedPercent(_ value: Double) -> String {
        let clamped = clamped(value)
        if isZero(clamped) { return "0%" }
        return String(format: "%+.0f%%", clamped * 100)
    }

    static func isZero(_ value: Double) -> Bool {
        abs(value) < 0.000_001
    }

    static func clamped(_ value: Double) -> Double {
        min(max(value, -1), 1)
    }
}

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
    @State private var sceneDescriptorsExpanded = false
    @State private var showDiagnostics = false
    @State private var zeroDetentHapticTick = false
    @AppStorage("SensorFMTestView.controlHand") private var controlHand = "right"

    private var isLeftHanded: Bool { controlHand == "left" }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= geo.size.height {
                landscapeModulationSurface
            } else {
                portraitModulationSurface
            }
        }
        .background(SynthColors.background.ignoresSafeArea())
        .safeAreaPadding(.top, 8)
        .sheet(isPresented: $showDiagnostics) {
            diagnosticsSheet
        }
        .sensoryFeedback(.selection, trigger: zeroDetentHapticTick)
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

    // MARK: - Adaptive modulation surface

    @ViewBuilder
    private var landscapeModulationSurface: some View {
        HStack(spacing: 0) {
            if isLeftHanded {
                matrixColumn
                verticalDivider
                contextColumn
            } else {
                contextColumn
                verticalDivider
                matrixColumn
            }
        }
    }

    private var portraitModulationSurface: some View {
        VStack(spacing: 0) {
            sectionHeader("SCENE FINGERPRINT + MATRIX")
            selectedCellEditor
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 16) {
                    sceneFingerprintPanel
                    modulationMatrixPanel
                    playStopRow
                    fmBaseControls
                    handednessControl
                    diagnosticsButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .background(SynthColors.surface)
    }

    private var contextColumn: some View {
        VStack(spacing: 0) {
            sectionHeader("CONTEXT + FM")
            playStopRow
            SynthColors.divider.frame(height: 1)
            VStack(spacing: 8) {
                sceneFingerprintPanel
                fmBaseControls
                handednessControl
                diagnosticsButton
            }
            .padding(12)
            Spacer(minLength: 0)
        }
        .frame(width: 308)
        .background(SynthColors.surface)
    }

    private var matrixColumn: some View {
        VStack(spacing: 0) {
            sectionHeader("MODULATION MATRIX")
            modulationMatrixPanel
                .padding(12)
            selectedCellEditor
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
                .safeAreaPadding(.bottom, 16)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(SynthColors.background)
    }

    private var verticalDivider: some View {
        SynthColors.divider.frame(width: 1)
    }

    // MARK: - Scene Fingerprint

    private var sceneFingerprintPanel: some View {
        let live = sceneAnalyzer.currentLiveFields
        let state = sceneAnalyzer.generatedState
        let seedHash = sceneAnalyzer.candidateFingerprint.map { String($0.seedHash, radix: 16, uppercase: true) } ?? "NO SEED"
        let stateLabel = sceneAnalyzer.candidateFingerprint == nil ? "SCENE PREVIEW" : "SCENE BASE"

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

            DisclosureGroup(isExpanded: $sceneDescriptorsExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    descriptorRow("ROOM ENERGY", value: live.roomEnergyEnvelope, color: SynthColors.sensorGreen)
                    descriptorRow("BRIGHTNESS", value: live.spectralBrightnessEnvelope, color: SynthColors.accent)
                    descriptorRow("BASS PRESSURE", value: live.bassPressureEnvelope, color: SynthColors.accentBlue)
                    descriptorRow("SURFACE VIBE", value: live.surfaceVibrationEnvelope, color: SynthColors.divider)
                    descriptorRow("SURFACE IMPACT", value: live.surfaceImpactEnvelope, color: SynthColors.accent)
                    descriptorRow("DEVICE STILL", value: live.deviceStillnessEnvelope, color: SynthColors.sensorGreen)
                }
                .padding(.top, 4)
            } label: {
                Text("SCENE DESCRIPTORS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(SynthColors.textSecondary)
            }
            .tint(SynthColors.accent)

            Text(stateLabel + String(format: "  carrier %.0fHz  ratio %.1f  index %.2f  amp %d%%",
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

            if sceneAnalyzer.savedFingerprint == sceneAnalyzer.candidateFingerprint,
               sceneAnalyzer.candidateFingerprint != nil {
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
                VStack(alignment: .trailing, spacing: 2) {
                    Text("9 SOURCES · SWIPE")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(SynthColors.accent)
                    Text("\(selectedSource.label) → \(selectedTarget.label)")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(SynthColors.textSecondary)
                        .lineLimit(1)
                }
            }

            ScrollView(.vertical, showsIndicators: true) {
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
            }
            .frame(maxHeight: 340)
            .accessibilityIdentifier("modulation.matrix.viewport")
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
            Text("LIVE \(format(target, bridge.outputValue(for: target)))")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(bridge.outputIsClamped(target) ? Color.red.opacity(0.9) : SynthColors.textSecondary)
        }
        .padding(.horizontal, 6)
        .frame(width: 116, height: 60, alignment: .leading)
        .background(selected ? SynthColors.accent.opacity(0.15) : Color.clear)
        .cornerRadius(6)
    }

    private func matrixCell(source: SensorModulationSource, target: SensorModulationTarget) -> some View {
        let selected = source == selectedSource && target == selectedTarget
        let amount = bridge.amount(source: source, target: target)
        let active = abs(amount) > 0.000_001
        let text = selected || active ? signedPercent(amount) : ""
        let stateText = active ? "ACTIVE" : (selected ? "SELECTED · NEUTRAL" : "")
        let accessibilityValue = stateText.isEmpty
            ? signedPercent(amount)
            : "\(signedPercent(amount)) · \(stateText)"
        let activationHint = selected && !active
            ? "Selected but neutral. Adjust amount to activate this route"
            : (active ? "Active route. Double-tap to remove" : "Select this modulation route")

        return Button {
            selectedSource = source
            selectedTarget = target
        } label: {
            VStack(spacing: 2) {
                Text(text)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(active || selected ? SynthColors.textPrimary : SynthColors.textSecondary)
                if selected && !active {
                    Text("SELECTED · NEUTRAL")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(SynthColors.textPrimary)
                        .minimumScaleFactor(0.7)
                    Text("ADJUST TO ACTIVATE")
                        .font(.system(size: 6, weight: .bold, design: .monospaced))
                        .foregroundColor(SynthColors.textPrimary)
                        .minimumScaleFactor(0.65)
                } else if active {
                    Text("ACTIVE")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(SynthColors.textPrimary)
                }
            }
            .frame(width: 92, height: 60)
            .background(cellColor(amount: amount, selected: selected))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selected ? SynthColors.accent : Color.clear, lineWidth: 2)
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onTapGesture(count: 2) {
            guard active else { return }
            bridge.setAmount(0, source: source, target: target)
        }
        .accessibilityLabel("\(source.label) to \(target.label)")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(activationHint)
    }

    private var selectedCellEditor: some View {
        let amount = bridge.amount(source: selectedSource, target: selectedTarget)
        let amountText = signedPercent(amount)
        let stateText = ModulationAmountInteraction.isZero(amount) ? "SELECTED · NEUTRAL" : "ACTIVE"

        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("LIVE SOURCE")
                    Spacer()
                    Text(selectedSource.label)
                }
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(SynthColors.textSecondary)
                HStack(spacing: 8) {
                    SensorBar(value: bridge.sourceValue(for: selectedSource), color: color(for: selectedSource))
                    Text(String(format: "%.2f", bridge.sourceValue(for: selectedSource)))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(SynthColors.textPrimary)
                        .frame(width: 36, alignment: .trailing)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SELECTED ROUTE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(SynthColors.textSecondary)
                    Text("\(selectedSource.label) → \(selectedTarget.label)")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(SynthColors.textSecondary)
                }
                Spacer()
                Button {
                    bridge.setAmount(0, source: selectedSource, target: selectedTarget)
                } label: {
                    Text(amountText)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(amount < 0 ? SynthColors.accentBlue : (amount > 0 ? SynthColors.accent : SynthColors.textPrimary))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset selected modulation route to zero")
                .accessibilityHint("Sets the selected route amount to zero")
            }

            HStack(spacing: 8) {
                Text("STATE \(stateText)")
                Spacer()
                Text("TAP VALUE TO RESET")
            }
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(SynthColors.textSecondary)

            if !ModulationAmountInteraction.isZero(amount) {
                Button {
                    clearSelectedRoute()
                } label: {
                    Label("REMOVE ROUTE", systemImage: "trash")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(SynthColors.background)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove selected modulation route")
                .accessibilityHint("Clears only the selected route and returns it to zero")
            }

            BipolarAmountControl(
                value: amountBinding(source: selectedSource, target: selectedTarget),
                amountText: amountText
            ) {
                zeroDetentHapticTick.toggle()
            }
            .accessibilityIdentifier("modulation.amount.slider")

            HStack(spacing: 8) {
                Text("BASE \(format(selectedTarget, bridge.baseValue(for: selectedTarget)))")
                Spacer()
                Text("LIVE \(format(selectedTarget, bridge.outputValue(for: selectedTarget)))")
                if bridge.outputIsClamped(selectedTarget) {
                    Text("CLAMPED")
                        .foregroundColor(Color.red.opacity(0.9))
                }
            }
            .font(.system(size: 8, weight: .semibold, design: .monospaced))
            .foregroundColor(SynthColors.textSecondary)

            HStack(spacing: 10) {
                if isLeftHanded {
                    editorButton("+") { bridge.stepAmount(source: selectedSource, target: selectedTarget, by: 0.01) }
                    editorButton("−") { bridge.stepAmount(source: selectedSource, target: selectedTarget, by: -0.01) }
                } else {
                    editorButton("−") { bridge.stepAmount(source: selectedSource, target: selectedTarget, by: -0.01) }
                    editorButton("+") { bridge.stepAmount(source: selectedSource, target: selectedTarget, by: 0.01) }
                }
            }
        }
        .padding(10)
        .background(SynthColors.background.opacity(0.55))
        .cornerRadius(8)
        .accessibilityIdentifier("modulation.route.editor")
    }

    private func clearSelectedRoute() {
        bridge.setAmount(0, source: selectedSource, target: selectedTarget)
    }

    private func amountBinding(source: SensorModulationSource, target: SensorModulationTarget) -> Binding<Double> {
        Binding(
            get: { bridge.amount(source: source, target: target) },
            set: { value in bridge.setAmount(ModulationAmountInteraction.clamped(value), source: source, target: target) }
        )
    }

    private func editorButton(_ title: String, action: @escaping () -> Void) -> some View {
        let accessibilityLabel = title == "−" ? "Decrease modulation by one percent" : "Increase modulation by one percent"

        return Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(SynthColors.background)
                .frame(minWidth: 44, minHeight: 44)
                .background(SynthColors.accent)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
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
        VStack(spacing: 8) {
            baseSlider(.carrierFrequency, color: SynthColors.accent)
            SynthColors.divider.opacity(0.4).frame(height: 0.5)
            baseSlider(.modulatorRatio, color: SynthColors.accentBlue)
            SynthColors.divider.opacity(0.4).frame(height: 0.5)
            baseSlider(.modulationIndex, color: SynthColors.accent)
            SynthColors.divider.opacity(0.4).frame(height: 0.5)
            baseSlider(.amplitude, color: SynthColors.sensorGreen)
        }
        .padding(10)
        .background(SynthColors.surfaceRaised)
        .cornerRadius(8)
    }

    private func baseSlider(_ target: SensorModulationTarget, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FMParameterSlider(
                label: target.label,
                value: baseBinding(target),
                range: target.range,
                step: target.step,
                displayValue: format(target, bridge.baseValue(for: target)),
                color: color
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

    private var handednessControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CONTROL HAND")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(SynthColors.textSecondary)
            Picker("Control hand", selection: $controlHand) {
                Text("RIGHT").tag("right")
                Text("LEFT").tag("left")
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Control hand")
            .accessibilityValue(isLeftHanded ? "Left" : "Right")
            .accessibilityIdentifier("Control hand")
        }
        .padding(12)
        .background(SynthColors.surfaceRaised)
        .cornerRadius(8)
    }

    private var diagnosticsButton: some View {
        Button {
            showDiagnostics = true
        } label: {
            Text("DIAG")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(SynthColors.background)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(SynthColors.accent)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Diagnostics")
    }

    private var diagnosticsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    micDebugPanel
                    rawSensorPanel
                }
                .padding(16)
            }
            .background(SynthColors.background.ignoresSafeArea())
            .navigationTitle("Diagnostics")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close diagnostics") { showDiagnostics = false }
                }
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("modulation.diagnostics")
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
                .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
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
        ModulationAmountInteraction.formattedPercent(value)
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

private struct BipolarAmountControl: View {
    @Binding var value: Double
    let amountText: String
    let onDragEnteredZero: () -> Void

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let horizontalInset = min(CGFloat(14), width / 2)
            let usableWidth = max(width - horizontalInset * 2, 1)
            let centerX = width / 2
            let clampedValue = ModulationAmountInteraction.clamped(value)
            let thumbX = horizontalInset + CGFloat((clampedValue + 1) / 2) * usableWidth
            let fillColor = clampedValue < 0 ? SynthColors.accentBlue : SynthColors.accent

            ZStack {
                Capsule()
                    .fill(SynthColors.surfaceRaised)
                    .frame(height: 8)
                    .position(x: centerX, y: 22)

                Capsule()
                    .fill(fillColor)
                    .frame(width: max(abs(thumbX - centerX), 2), height: 8)
                    .opacity(ModulationAmountInteraction.isZero(clampedValue) ? 0 : 1)
                    .position(x: (thumbX + centerX) / 2, y: 22)

                Rectangle()
                    .fill(ModulationAmountInteraction.isZero(clampedValue) ? SynthColors.textPrimary : SynthColors.textSecondary)
                    .frame(width: 2, height: 26)
                    .position(x: centerX, y: 22)

                Circle()
                    .fill(fillColor)
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(SynthColors.textPrimary.opacity(0.8), lineWidth: 1))
                    .position(x: thumbX, y: 22)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in updateAmount(locationX: gesture.location.x, width: width) }
            )
        }
        .frame(height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Modulation amount")
        .accessibilityValue(amountText)
        .accessibilityHint("Swipe up or down to adjust by one percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = ModulationAmountInteraction.nudgeAmount(value, by: 0.01)
            case .decrement:
                value = ModulationAmountInteraction.nudgeAmount(value, by: -0.01)
            @unknown default:
                break
            }
        }
    }

    private func updateAmount(locationX: CGFloat, width: CGFloat) {
        let horizontalInset = min(CGFloat(14), width / 2)
        let usableWidth = max(width - horizontalInset * 2, 1)
        let clampedX = min(max(locationX, horizontalInset), width - horizontalInset)
        let raw = Double((clampedX - horizontalInset) / usableWidth) * 2 - 1
        let wasAtZero = ModulationAmountInteraction.isZero(value)
        let next = ModulationAmountInteraction.dragAmount(raw)
        value = next
        if !wasAtZero && ModulationAmountInteraction.isZero(next) {
            onDragEnteredZero()
        }
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
