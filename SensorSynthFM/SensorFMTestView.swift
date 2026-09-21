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

    let startLiveRuntime: Bool

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
    @State private var showMatrix = false
    @State private var noteState = NoteEntryState()
    @State private var holdControlIsPressed = false
    @State private var holdPressConsumed = false
    @State private var beganTouchCount = 0
    @State private var movedTouchCount = 0
    @State private var releasedTouchCount = 0
    @State private var lastTouchEvent = "IDLE"
    @State private var firstTouchPitch: Double?
    @State private var lastTouchPitch: Double?
    @AppStorage("SensorFMTestView.controlHand") private var controlHand = "right"

    private var isLeftHanded: Bool { controlHand == "left" }

    init(startLiveRuntime: Bool = true) {
        self.startLiveRuntime = startLiveRuntime
    }

    var body: some View {
        GeometryReader { geo in
            if showMatrix {
                VStack(spacing: 0) {
                    matrixReturnBar
                    if geo.size.width >= geo.size.height {
                        landscapeModulationSurface
                    } else {
                        portraitModulationSurface
                    }
                }
            } else {
                performanceSurface
            }
        }
        .background(SynthColors.background.ignoresSafeArea())
        .safeAreaPadding(.top, 8)
        .safeAreaPadding(.bottom, 18)
        .sheet(isPresented: $showDiagnostics) {
            diagnosticsSheet
        }
        .sensoryFeedback(.selection, trigger: zeroDetentHapticTick)
        .preferredColorScheme(.dark)
        .onAppear {
            bridge.performanceMode = true
            guard startLiveRuntime else { return }
            sensors.start()
            engine.start(allowMicrophoneInput: true)
            bridge.start(sensors: sensors, engine: engine, sceneAnalyzer: sceneAnalyzer)
            startSceneFingerprintUpdates()
        }
        .onDisappear {
            stopSceneFingerprintUpdates()
            releaseAllTouches(reason: "view disappeared")
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

    // MARK: - Performance note entry

    private var performanceSurface: some View {
        HStack(spacing: 8) {
            if isLeftHanded {
                controlRail
                performanceNoteArea
            } else {
                performanceNoteArea
                controlRail
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .background(SynthColors.background)
    }

    private var performanceNoteArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("PERFORMANCE")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(SynthColors.textPrimary)
                Text("PITCH \(noteState.mode == .quantized ? "QUANTIZED" : "FREEHAND")")
                    .accessibilityIdentifier("performance.pitch.mode")
                Text(noteState.rangeLabel)
                    .accessibilityIdentifier("performance.pitch.range")
                Text("VOICES \(noteState.activeAndHeldVoiceCount)/\(FMEngine.voiceCapacity)")
                    .accessibilityIdentifier("performance.active.voice.count")
                Spacer(minLength: 0)
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(SynthColors.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            ZStack {
                // The note surface is primary. There is deliberately no redundant note gutter.
                VStack(spacing: 1) {
                    ForEach(0..<PitchMapper.laneCount, id: \.self) { lane in
                        Rectangle()
                            .fill(lane.isMultiple(of: 2) ? SynthColors.surfaceRaised : SynthColors.surface)
                            .overlay(SynthColors.divider.frame(height: 1), alignment: .bottom)
                            .accessibilityHidden(true)
                    }
                }

                PerformanceNoteSurface { event in
                    handleNoteSurfaceEvent(event)
                }
                .accessibilityIdentifier("performance.note.surface")

                GeometryReader { geo in
                    // Active touches use a solid circle and an explicit ACTIVE label.
                    ForEach(noteState.activeTouches) { touch in
                        let point = CGPoint(
                            x: geo.size.width * CGFloat(touch.normalizedX),
                            y: geo.size.height * CGFloat(touch.normalizedY)
                        )
                        let feedback = NoteFeedbackFormatter.feedback(for: touch.target, mode: noteState.mode)
                        Circle()
                            .stroke(SynthColors.accent, lineWidth: 3)
                            .frame(width: 88, height: 88)
                            .overlay(Circle().stroke(SynthColors.textPrimary, lineWidth: 1).padding(6))
                            .position(point)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("ACTIVE touch voice \(touch.voiceID + 1)")
                            .accessibilityValue(feedback.label)

                        feedbackLabel("ACTIVE · \(feedback.label)", color: SynthColors.textPrimary)
                            .position(
                                x: handednessLabelX(in: geo.size.width),
                                y: min(max(point.y, 24), geo.size.height - 24)
                            )
                            .accessibilityHidden(true)
                    }

                    // Released indicators are dashed and remain briefly for the deterministic envelope window.
                    ForEach(noteState.releasedIndicators) { indicator in
                        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                            let point = CGPoint(
                                x: geo.size.width * CGFloat(indicator.normalizedX),
                                y: geo.size.height * CGFloat(indicator.normalizedY)
                            )
                            let feedback = NoteFeedbackFormatter.feedback(for: indicator.target, mode: noteState.mode)
                            Circle()
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                                .foregroundColor(SynthColors.accent)
                                .frame(width: 30, height: 30)
                                .position(point)
                                .opacity(indicator.opacity(at: timeline.date))
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("RELEASED envelope voice \(indicator.voiceID + 1)")
                                .accessibilityValue(feedback.label)
                        }
                    }

                    // Held markers use the fixed pitch-edge marker, never the old touch X position.
                    ForEach(noteState.heldNotes.values.sorted { $0.pitch > $1.pitch }) { held in
                        let markerY = heldMarkerY(for: held, in: geo.size.height)
                        let edgeX = isLeftHanded ? CGFloat(geo.size.width - 14) : 14
                        let feedback = NoteFeedbackFormatter.feedback(for: held.target, mode: noteState.mode)
                        VStack(spacing: 2) {
                            Rectangle()
                                .frame(width: 8, height: 24)
                            Text("HELD")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                            Text(feedback.label)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        .foregroundColor(SynthColors.sensorGreen)
                        .position(x: edgeX, y: markerY)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("HELD pitch")
                        .accessibilityValue(feedback.label)
                        .accessibilityAction(named: Text("Remove held note")) {
                            removeHeldNote(held)
                        }
                    }
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SynthColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(SynthColors.divider, lineWidth: 1))
            .accessibilityIdentifier("performance.note.surface.container")

            HStack(spacing: 8) {
                Text("ACTIVE HALOS · RELEASED ENVELOPES · HELD EDGE MARKERS")
                Spacer(minLength: 0)
                Text("SENSOR TIMBRE UNDERLAY: \(Int((bridge.performanceTimbreAmount * 100).rounded()))%")
                    .accessibilityIdentifier("performance.sensor.timbre")
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(SynthColors.textSecondary)

            Text(touchDiagnosticText)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(SynthColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityIdentifier("performance.touch.lifecycle")
                .accessibilityValue(touchDiagnosticText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func feedbackLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(SynthColors.background.opacity(0.9))
            .cornerRadius(4)
    }

    private func handednessLabelX(in width: CGFloat) -> CGFloat {
        isLeftHanded ? min(100, width - 80) : max(width - 100, 80)
    }

    private func heldMarkerY(for held: HeldNote, in height: CGFloat) -> CGFloat {
        CGFloat(held.normalizedY) * height
    }

    private var touchDiagnosticText: String {
        let first = firstTouchPitch.map { String(Int($0.rounded())) } ?? "--"
        let last = lastTouchPitch.map { String(Int($0.rounded())) } ?? "--"
        let changed: Bool
        if let firstTouchPitch, let lastTouchPitch {
            changed = abs(firstTouchPitch - lastTouchPitch) > 0.000_001
        } else {
            changed = false
        }
        return "TOUCH B\(beganTouchCount) M\(movedTouchCount) R\(releasedTouchCount) · LAST \(lastTouchEvent) · PITCH \(first)→\(last) · PITCH CHANGED \(changed ? "YES" : "NO")"
    }

    private var controlRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OFF-HAND RAIL")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(SynthColors.textSecondary)

            HStack(spacing: 6) {
                railButton("QUANTIZED", identifier: "performance.pitch.quantized", active: noteState.mode == .quantized) {
                    setPitchMode(.quantized)
                }
                railButton("FREEHAND", identifier: "performance.pitch.freehand", active: noteState.mode == .freehand) {
                    setPitchMode(.freehand)
                }
            }

            HStack(spacing: 6) {
                railButton("OCT −", identifier: "performance.octave.down", active: false, disabled: noteState.octaveOffset <= -2) {
                    setOctaveOffset(noteState.octaveOffset - 1)
                }
                railButton("OCT +", identifier: "performance.octave.up", active: false, disabled: noteState.octaveOffset >= 2) {
                    setOctaveOffset(noteState.octaveOffset + 1)
                }
            }

            Text(noteState.rangeLabel)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(SynthColors.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(SynthColors.surfaceRaised)
                .cornerRadius(7)

            railButton("HOLD", identifier: "performance.hold", active: noteState.isHoldEnabled, tracksHoldPress: true) {
                toggleHoldFromControl()
            }
            .accessibilityValue(noteState.isHoldEnabled ? "Enabled. Hold while selecting a held pitch to remove it." : "Disabled")
            .accessibilityHint("Releasing a note while enabled keeps one unattended pitch sounding.")

            railButton("RELEASE ALL", identifier: "performance.release.touches", active: false) {
                releaseAllTouches(reason: "manual release")
            }
            railButton("MATRIX", identifier: "performance.matrix", active: false) {
                enterMatrixMode()
            }

            Text("CONTROL HAND")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(SynthColors.textSecondary)
            HStack(spacing: 6) {
                railButton("LEFT", identifier: "performance.hand.left", active: isLeftHanded) {
                    controlHand = "left"
                }
                railButton("RIGHT", identifier: "performance.hand.right", active: !isLeftHanded) {
                    controlHand = "right"
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: 164)
        .background(SynthColors.surface)
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("performance.control.rail")
    }

    @ViewBuilder
    private func railButton(
        _ title: String,
        identifier: String,
        active: Bool,
        disabled: Bool = false,
        tracksHoldPress: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let button = Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(disabled ? SynthColors.textSecondary : SynthColors.background)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(disabled ? SynthColors.divider.opacity(0.3) : (active ? SynthColors.sensorGreen : SynthColors.accent))
                .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityIdentifier(identifier)

        if tracksHoldPress {
            button.simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in holdControlIsPressed = true }
                    .onEnded { _ in
                        holdControlIsPressed = false
                        DispatchQueue.main.async { holdPressConsumed = false }
                    }
            )
        } else {
            button
        }
    }

    private var matrixReturnBar: some View {
        HStack {
            Button {
                returnToPerformanceMode()
            } label: {
                Text("PERFORMANCE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(SynthColors.background)
                    .frame(minWidth: 132, minHeight: 44)
                    .background(SynthColors.accent)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("performance.return")
            Spacer()
            Text("MATRIX MODE · PERFORMANCE CONFIGURATION PRESERVED")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(SynthColors.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(SynthColors.surface)
    }

    private func enterMatrixMode() {
        releaseAllTouches(reason: "entering matrix")
        engine.noteOff()
        bridge.performanceMode = false
        showMatrix = true
    }

    private func returnToPerformanceMode() {
        releaseAllTouches(reason: "returning to performance")
        engine.noteOff()
        bridge.performanceMode = true
        showMatrix = false
    }

    private func laneLabel(_ lane: Int) -> String {
        let midi = noteState.scale.midiNote(forLane: lane) + noteState.octaveOffset * 12
        return "\(midiName(midi))"
    }

    private func midiName(_ midi: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = midi / 12 - 1
        return "\(names[((midi % 12) + 12) % 12])\(octave)"
    }

    private func setPitchMode(_ mode: PitchMode) {
        releaseDisplacedHeldNotes(noteState.setMode(mode))
        refreshPerformanceVoiceFrequencies()
    }

    private func setOctaveOffset(_ offset: Int) {
        releaseDisplacedHeldNotes(noteState.setOctaveOffset(offset))
        refreshPerformanceVoiceFrequencies()
    }

    private func refreshPerformanceVoiceFrequencies() {
        for held in noteState.heldNotes.values {
            engine.setFrequency(
                voiceID: held.voiceID,
                frequency: held.target.frequency,
                rampMilliseconds: NoteEntryState.pitchRemapRampMilliseconds
            )
        }
        for touch in noteState.activeTouches {
            engine.setFrequency(
                voiceID: touch.voiceID,
                frequency: touch.target.frequency,
                rampMilliseconds: NoteEntryState.pitchRemapRampMilliseconds
            )
        }
    }

    private func releaseDisplacedHeldNotes(_ displaced: [HeldNote]) {
        for held in displaced where !noteState.isVoiceTouched(held.voiceID) {
            engine.noteOff(voiceID: held.voiceID)
        }
    }

    private func removeHeldNote(_ held: HeldNote) {
        guard let removed = noteState.removeHeldNote(id: held.id) else { return }
        if !noteState.isVoiceTouched(removed.voiceID) {
            engine.noteOff(voiceID: removed.voiceID)
        }
    }

    private func setHoldEnabled(_ enabled: Bool) {
        let released = noteState.setHoldEnabled(enabled)
        if !enabled {
            for held in released {
                if !noteState.isVoiceTouched(held.voiceID) {
                    engine.noteOff(voiceID: held.voiceID)
                }
            }
        }
    }

    private func toggleHoldFromControl() {
        if holdPressConsumed {
            holdPressConsumed = false
            return
        }
        setHoldEnabled(!noteState.isHoldEnabled)
    }

    private func handleNoteSurfaceEvent(_ event: NoteEntrySurfaceEvent) {
        switch event {
        case let .began(id, normalizedX, normalizedY):
            if holdControlIsPressed, let held = noteState.removeHeldPitch(normalizedY: normalizedY) {
                // The Hold rail's simultaneous press gesture is the native, testable
                // "hold control while selecting" removal interaction.
                engine.noteOff(voiceID: held.voiceID)
                holdPressConsumed = true
                lastTouchEvent = "HELD REMOVED"
                return
            }
            guard let touch = noteState.beginTouch(id: id, normalizedX: normalizedX, normalizedY: normalizedY) else { return }
            recordBegan(touch)
            engine.noteOn(voiceID: touch.voiceID, frequency: touch.target.frequency)
        case let .moved(id, normalizedX, normalizedY):
            guard let touch = noteState.moveTouch(id: id, normalizedX: normalizedX, normalizedY: normalizedY) else { return }
            recordMoved(touch)
            engine.setFrequency(
                voiceID: touch.voiceID,
                frequency: touch.target.frequency,
                rampMilliseconds: NoteEntryState.pitchRemapRampMilliseconds
            )
        case let .ended(id), let .cancelled(id):
            guard let touch = noteState.endTouch(id: id) else { return }
            recordReleased(touchCount: 1)
            if !noteState.isVoiceHeld(touch.voiceID) {
                engine.noteOff(voiceID: touch.voiceID)
            }
            if let indicatorID = noteState.releasedIndicators.last?.id {
                scheduleReleasedIndicatorClear(id: indicatorID)
            }
        case let .releaseAll(reason):
            releaseAllTouches(reason: reason)
        }
    }

    private func scheduleReleasedIndicatorClear(id: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + NoteEntryState.releasedIndicatorLifetimeMilliseconds / 1000.0) {
            noteState.removeReleasedIndicator(id: id)
        }
    }
    private func recordBegan(_ touch: NoteTouch) {
        beganTouchCount += 1
        lastTouchEvent = "BEGAN"
        firstTouchPitch = firstTouchPitch ?? touch.pitch
        lastTouchPitch = touch.pitch
    }

    private func recordMoved(_ touch: NoteTouch) {
        movedTouchCount += 1
        lastTouchEvent = "MOVED"
        lastTouchPitch = touch.pitch
    }

    private func recordReleased(touchCount: Int) {
        releasedTouchCount += touchCount
        lastTouchEvent = "RELEASED"
    }

    private func releaseAllTouches(reason: String) {
        holdControlIsPressed = false
        holdPressConsumed = false
        let released = noteState.releaseAll(reason: reason)
        if !released.isEmpty {
            recordReleased(touchCount: released.count)
        }
        engine.releaseAllVoices()
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
                        .accessibilityIdentifier("modulation.matrix.selection.context")
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
        .accessibilityIdentifier("modulation.source.\(source.rawValue)")
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
        .accessibilityIdentifier("modulation.target.\(target.rawValue)")
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
        .accessibilityIdentifier("modulation.cell.source.\(source.rawValue).target.\(target.rawValue)")
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
                        .accessibilityIdentifier("modulation.selected.route.context")
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
            .opacity(ModulationAmountInteraction.isZero(amount) ? 0 : 1)
            .allowsHitTesting(!ModulationAmountInteraction.isZero(amount))
            .disabled(ModulationAmountInteraction.isZero(amount))
            .accessibilityHidden(ModulationAmountInteraction.isZero(amount))
            .accessibilityLabel("Remove selected modulation route")
            .accessibilityHint("Clears only the selected route and returns it to zero")
            .accessibilityIdentifier("modulation.route.remove")

            BipolarAmountControl(
                value: amountBinding(source: selectedSource, target: selectedTarget),
                amountText: amountText
            ) {
                zeroDetentHapticTick.toggle()
            }

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
        .accessibilityElement(children: .contain)
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
        let accessibilityIdentifier = title == "−" ? "modulation.amount.decrease" : "modulation.amount.increase"

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
        .accessibilityIdentifier(accessibilityIdentifier)
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
        .accessibilityIdentifier("modulation.amount.slider")
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
