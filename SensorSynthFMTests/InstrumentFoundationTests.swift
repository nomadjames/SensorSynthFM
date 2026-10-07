// Native Mac/Xcode-runnable behavior tests. Linux contracts do NOT execute these.
import Foundation
import UIKit
import Testing
@testable import SensorSynthFM

@Suite(.serialized)
@MainActor
struct InstrumentFoundationTests {
    @Test func catalogPreservesIDsAndFiniteBounds() {
        #expect(SensorModulationTarget.carrierFrequency.rawValue == 0)
        #expect(SensorModulationTarget.amplitude.rawValue == 3)
        #expect(SensorModulationTarget.ampAttack.rawValue == 4)
        #expect(SensorModulationTarget.filterResonance.rawValue == 9)
        #expect(SensorModulationSource.deviceStillness.rawValue == 8)
        for target in SensorModulationTarget.allCases {
            for bad in [Double.nan, Double.infinity, -Double.infinity] {
                #expect(target.clamp(bad) == target.defaultValue)
                #expect(target.normalised(bad).isFinite)
            }
            for norm in [0.0, 0.25, 0.5, 0.75, 1.0] {
                #expect(abs(target.normalised(target.denormalised(norm)) - norm) < 0.000_001)
            }
        }
        #expect(abs(SensorModulationTarget.filterCutoff.denormalised(0.5) - 600) < 0.000_001)
        #expect(FilterMode.resonanceDecibels(1) == 6)
        #expect(FilterMode.bandwidthCents(1) == 300)
        #expect(FilterMode.bandwidthCents(0) == 2400)
    }

    @Test func invalidSourcesAndRoutesAreNeutralAndFinite() {
        var matrix = SensorModulationMatrix(seedDefaults: false)
        for target in SensorModulationTarget.allCases {
            matrix.setAmount(.nan, source: .roomEnergy, target: target)
            #expect(matrix.amount(source: .roomEnergy, target: target) == 0)
            matrix.setAmount(1, source: .gyroY, target: target)
        }
        var sources = SensorModulationSourceValues()
        sources.gyroY = .infinity
        sources.roomEnergy = .nan
        let output = matrix.evaluate(sources: sources)
        for target in SensorModulationTarget.allCases {
            #expect(abs(output.value(for: target) - target.defaultValue) < 0.000_001)
            #expect(output.value(for: target).isFinite)
        }
    }

    @Test func allContinuousTargetsReachSinkInOneFrame() {
        let sink = InstrumentRecordingSink()
        let bridge = SensorFMBridge(parameterSink: sink)
        bridge.performanceMode = true
        for target in SensorModulationTarget.allCases {
            let before = sink.frames
            bridge.setBaseValue(target.denormalised(0.25), for: target)
            #expect(sink.frames == before + 1)
            #expect(abs((sink.lastOutput?.value(for: target) ?? -1) - bridge.outputValue(for: target)) < 0.000_001)
            let neutral = bridge.outputValue(for: target)
            bridge.setAmount(0.2, source: .deviceStillness, target: target)
            #expect(bridge.outputValue(for: target) > neutral)
            bridge.setAmount(0, source: .deviceStillness, target: target)
            #expect(abs(bridge.outputValue(for: target) - neutral) < 0.000_001)
        }
        #expect(sink.preserveTouchPitch)
        bridge.setFilter(mode: .bandPass, bypassed: false)
        #expect(sink.filterMode == .bandPass)
        #expect(!sink.filterBypassed)
    }

    @Test func nativeSliderHitBoundsMatchAccessibleBounds() {
        let slider = InstrumentUISlider(frame: CGRect(x: 0, y: 0, width: 240, height: 44))
        #expect(slider.point(inside: CGPoint(x: 120, y: 1), with: nil))
        #expect(slider.point(inside: CGPoint(x: 120, y: 43), with: nil))
        #expect(!slider.point(inside: CGPoint(x: 120, y: -1), with: nil))
        #expect(slider.accessibilityFrame.height == slider.bounds.height)
        #expect(slider.accessibilityFrame.height == 44)
    }

    @Test func nativeStageEndpointsMatchSelectedDurations() throws {
        let engine = FMEngine()
        defer { engine.stop() }
        // Check actual native parameters against independent endpoint equations,
        // not against the calibration helper itself.
        for seconds in [0.02, 0.2, 1.2] {
            engine.ampAttack = seconds
            engine.ampDecay = seconds
            engine.ampRelease = seconds
            let voice = try #require(engine.diagnostics(voiceID: 0))
            #expect(abs(exp(-seconds / (0.6 * voice.attack)) - 0.01) < 0.000_01)
            #expect(abs(exp(-seconds / voice.decay) - 0.01) < 0.000_01)
            #expect(abs(exp(-seconds / voice.release) - 0.001) < 0.000_01)
        }
    }

    @Test func realEngineReceivesOneCoherentFrameAndPreservesManualPitch() throws {
        let engine = FMEngine()
        defer { engine.stop() }
        let bridge = SensorFMBridge(parameterSink: engine)
        bridge.performanceMode = true
        engine.noteOn(voiceID: 0, frequency: 333)
        let before = engine.parameterFrameCount
        bridge.setBaseValue(1.2, for: .ampAttack)
        #expect(engine.parameterFrameCount == before + 1)
        let voice = try #require(engine.diagnostics(voiceID: 0))
        #expect(abs(voice.attack - (1.2 / (0.6 * log(100.0)))) < 0.000_01)
        #expect(engine.voiceStates[0].frequency == 333)
        let gateCount = voice.gateOpenCount
        bridge.setBaseValue(1800, for: .carrierFrequency)
        #expect(engine.voiceStates[0].frequency == 333)
        #expect(engine.diagnostics(voiceID: 0)?.gateOpenCount == gateCount)
        engine.setFrequency(voiceID: 0, frequency: 666, rampMilliseconds: 20)
        #expect(engine.lastPitchRampMilliseconds == 20)
        #expect(engine.diagnostics(voiceID: 0)?.gateOpenCount == gateCount)
        let newTargets: [SensorModulationTarget] = [.ampAttack, .ampDecay, .ampSustain, .ampRelease, .filterCutoff, .filterResonance]
        for target in newTargets {
            let frames = engine.parameterFrameCount
            bridge.setBaseValue(target.denormalised(0.4), for: target)
            #expect(engine.parameterFrameCount == frames + 1)
        }
        let native = try #require(engine.diagnostics(voiceID: 0))
        let nativeValues = [native.attack, native.decay, native.sustain, native.release, native.cutoff,
                            native.resonanceDB / 6]
        for (target, actual) in zip(newTargets, nativeValues) {
            let uiValue = bridge.outputValue(for: target)
            let expected: Double
            switch target {
            case .ampAttack: expected = uiValue / (0.6 * log(100.0))
            case .ampDecay: expected = uiValue / log(100.0)
            case .ampRelease: expected = uiValue / log(1000.0)
            default: expected = uiValue
            }
            #expect(abs(actual - expected) < 0.001)
        }
        #expect(native.gateOpenCount == gateCount)
    }

    @Test func releaseSnapshotSurvivesControlFrames() throws {
        let engine = FMEngine()
        defer { engine.stop() }
        let bridge = SensorFMBridge(parameterSink: engine)
        bridge.setBaseValue(1.2, for: .ampRelease)
        bridge.setBaseValue(0.6, for: .amplitude)
        engine.noteOn(voiceID: 0, frequency: 440)
        engine.noteOff(voiceID: 0)
        let release = try #require(engine.diagnostics(voiceID: 0))
        #expect(release.isReleasing)
        #expect(abs((release.releaseSeconds ?? 0) - 1.2) < 0.000_001)
        for _ in 0..<30 {
            bridge.setBaseValue(0.02, for: .ampRelease)
            bridge.setBaseValue(0, for: .ampSustain)
            bridge.setBaseValue(0, for: .amplitude)
        }
        let after = try #require(engine.diagnostics(voiceID: 0))
        #expect(after.isReleasing)
        #expect(abs(after.release - (1.2 / log(1000.0))) < 0.000_01)
        #expect(after.releaseSeconds == release.releaseSeconds)
        #expect(after.oscillatorAmplitude == release.oscillatorAmplitude)
        #expect(after.gateOpenCount == release.gateOpenCount)
        #expect(after.oscillatorStarted)
        engine.completeRelease(voiceID: 0, generation: release.generation)
        #expect(engine.diagnostics(voiceID: 0)?.oscillatorStarted == false)
    }

    @Test func staleReleaseCannotStopReusedVoice() throws {
        let engine = FMEngine()
        defer { engine.stop() }
        engine.noteOn(voiceID: 0, frequency: 440)
        engine.noteOff(voiceID: 0)
        let oldToken = try #require(engine.diagnostics(voiceID: 0)).generation
        engine.noteOn(voiceID: 0, frequency: 880)
        engine.completeRelease(voiceID: 0, generation: oldToken)
        let reused = try #require(engine.diagnostics(voiceID: 0))
        #expect(reused.isActive && reused.oscillatorStarted)
        #expect(!reused.isReleasing)
        #expect(reused.generation != oldToken)
        #expect(reused.gateOpenCount == 2)
        #expect(engine.voiceStates[0].frequency == 880)
    }

    @Test func releaseAllAndStopSilenceActiveAndReleasingVoices() throws {
        let engine = FMEngine()
        defer { engine.stop() }
        engine.noteOn(voiceID: 0, frequency: 440)
        engine.noteOn(voiceID: 1, frequency: 660)
        engine.noteOff(voiceID: 1)
        let oldToken = try #require(engine.diagnostics(voiceID: 1)).generation
        engine.releaseAllVoices()
        engine.completeRelease(voiceID: 1, generation: oldToken)
        #expect(engine.activeVoiceCount == 0)
        #expect(!engine.isPlaying)
        for id in 0..<FMEngine.voiceCapacity {
            let voice = try #require(engine.diagnostics(voiceID: id))
            #expect(!voice.isActive && !voice.isReleasing && !voice.oscillatorStarted)
        }
        engine.noteOn(voiceID: 2, frequency: 220)
        engine.stop()
        #expect(engine.activeVoiceCount == 0)
        #expect(engine.diagnostics(voiceID: 2)?.oscillatorStarted == false)
    }

    @Test func nativeGraphKeepsIdentityAcrossControlChanges() throws {
        let engine = FMEngine()
        defer { engine.stop() }
        let baseline = try #require(engine.diagnostics(voiceID: 0))
        let other = try #require(engine.diagnostics(voiceID: 1))
        #expect(Set(baseline.filterNodeIDs + other.filterNodeIDs).count == 6)
        #expect(baseline.enabledFilters == [false, false, false])
        engine.noteOn(voiceID: 0, frequency: 440)
        for (index, mode) in FilterMode.allCases.enumerated() {
            engine.setFilter(mode: mode, bypassed: false)
            engine.filterCutoff = 1200
            engine.filterResonance = 1
            let voice = try #require(engine.diagnostics(voiceID: 0))
            #expect(voice.filterNodeIDs == baseline.filterNodeIDs)
            #expect(voice.enabledFilters == (0..<3).map { $0 == index })
            #expect(voice.cutoff == 1200)
            #expect(voice.resonanceDB == 6)
            #expect(voice.bandwidthCents == 300)
            #expect(voice.gateOpenCount == 1)
        }
        engine.setFilter(mode: .bandPass, bypassed: true)
        #expect(engine.diagnostics(voiceID: 0)?.enabledFilters == [false, false, false])
    }

    @Test func nativeParameterBoundaryRejectsNaNAndInvalidNoteInput() throws {
        let engine = FMEngine()
        defer { engine.stop() }
        engine.noteOn(voiceID: -1, frequency: 440)
        engine.noteOn(voiceID: 0, frequency: .nan)
        #expect(engine.activeVoiceCount == 0)
        engine.noteOn(voiceID: 0, frequency: 440)
        engine.amplitude = .infinity
        engine.ampAttack = .nan
        engine.ampRelease = -.infinity
        engine.filterCutoff = .nan
        engine.filterResonance = 100
        engine.setFrequency(voiceID: 0, frequency: .nan)
        let voice = try #require(engine.diagnostics(voiceID: 0))
        #expect(abs(voice.attack - (0.005 / (0.6 * log(100.0)))) < 0.000_001)
        #expect(abs(voice.release - (0.35 / log(1000.0))) < 0.000_001)
        #expect(voice.cutoff == 18_000)
        #expect(voice.resonanceDB == 6)
        #expect(engine.voiceStates[0].frequency == 440)
    }

    @Test func instrumentTransitionCancelsTouchesButPreservesHeldOwner() throws {
        let state = NoteEntryState()
        let engine = FMEngine()
        defer { engine.stop() }
        state.setHoldEnabled(true)
        let heldTouch = try #require(state.beginTouch(id: "held", normalizedY: 0.9))
        engine.noteOn(voiceID: heldTouch.voiceID, frequency: heldTouch.target.frequency)
        _ = state.endTouch(id: "held")
        let active = try #require(state.beginTouch(id: "active", normalizedY: 0.2))
        engine.noteOn(voiceID: active.voiceID, frequency: active.target.frequency)
        let cancelled = state.cancelSurfaceTouches(reason: "entering instrument")
        for touch in cancelled where !state.isVoiceHeld(touch.voiceID) {
            engine.noteOff(voiceID: touch.voiceID)
        }
        #expect(cancelled.count == 1)
        #expect(state.touches.isEmpty)
        #expect(state.heldNotes.count == 1)
        #expect(state.isVoiceHeld(heldTouch.voiceID))
        #expect(engine.diagnostics(voiceID: heldTouch.voiceID)?.isActive == true)
        #expect(engine.diagnostics(voiceID: active.voiceID)?.isReleasing == true)
        _ = state.releaseAll(reason: "entering matrix")
        engine.releaseAllVoices()
        #expect(state.activeAndHeldVoiceCount == 0)
        #expect(engine.activeVoiceCount == 0)
    }

    @Test func cancellationNeverCreatesHoldAndFeedbackSnapshotsRelease() throws {
        let state = NoteEntryState()
        state.setHoldEnabled(true)
        _ = state.beginTouch(id: "cancelled", normalizedY: 0.5)
        _ = state.endTouch(id: "cancelled", latchHold: false, releaseMilliseconds: 1200)
        #expect(state.heldNotes.isEmpty)
        let first = try #require(state.releasedIndicators.first)
        #expect(first.lifetimeMilliseconds == 1200)
        #expect(abs(first.opacity(at: first.releasedAt.addingTimeInterval(0.6)) - 0.5) < 0.000_001)
        _ = state.beginTouch(id: "second", normalizedY: 0.5)
        _ = state.endTouch(id: "second", latchHold: false, releaseMilliseconds: 20)
        let second = try #require(state.releasedIndicators.last)
        #expect(first.id != second.id)
        state.removeReleasedIndicator(id: first.id)
        #expect(state.releasedIndicators.map(\.id) == [second.id])
    }

    @Test func sceneGenerationPreservesNewBasesAndRouteRemovalPreservesOthers() {
        var matrix = SensorModulationMatrix(seedDefaults: false)
        matrix.setBaseValue(1.2, for: .ampRelease)
        matrix.setBaseValue(900, for: .filterCutoff)
        matrix.setAmount(0.2, source: .roomEnergy, target: .ampRelease)
        matrix.setAmount(-0.3, source: .spectralBrightness, target: .filterCutoff)
        matrix.applyBase(carrierFrequency: 330, modulatorRatio: 6, modulationIndex: 3, amplitude: 0.42)
        matrix.setAmount(0, source: .roomEnergy, target: .ampRelease)
        #expect(matrix.baseValue(for: .ampRelease) == 1.2)
        #expect(matrix.baseValue(for: .filterCutoff) == 900)
        #expect(matrix.amount(source: .spectralBrightness, target: .filterCutoff) == -0.3)
        #expect(matrix.amount(source: .roomEnergy, target: .ampRelease) == 0)
    }
}

@MainActor
private final class InstrumentRecordingSink: SensorFMParameterSink {
    var frames = 0
    var lastOutput: SensorModulationOutput?
    var preserveTouchPitch = false
    var filterMode: FilterMode = .lowPass
    var filterBypassed = true
    func apply(output: SensorModulationOutput, preserveTouchPitch: Bool) {
        frames += 1
        lastOutput = output
        self.preserveTouchPitch = preserveTouchPitch
    }
    func setFilter(mode: FilterMode, bypassed: Bool) {
        filterMode = mode
        filterBypassed = bypassed
    }
}
