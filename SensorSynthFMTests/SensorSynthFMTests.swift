//
//  SensorSynthFMTests.swift
//  SensorSynthFMTests
//
//  Created by nomad james on 2/16/26.
//

import Testing
@testable import SensorSynthFM

struct SensorSynthFMTests {

    @Test func audioSampleSnapshotRoundTripsAtomically() {
        let snapshot = AudioSampleSnapshot()
        snapshot.store(rms: 0.1, low: 0.2, mid: 0.3, high: 0.4, tapFrames: 512)
        let sample = snapshot.load()

        #expect(sample.rms == 0.1)
        #expect(sample.low == 0.2)
        #expect(sample.mid == 0.3)
        #expect(sample.high == 0.4)
        #expect(sample.tapFrames == 512)
    }

    @Test func runtimeIsSuppressedForHostedUnitTests() {
        #expect(
            !SensorSynthFMRuntimeMode.shouldStart(
                environment: ["XCTestConfigurationFilePath": "/tmp/tests.xctestconfiguration"]
            )
        )
    }

    @Test func runtimeStartsOutsideHostedUnitTests() {
        #expect(SensorSynthFMRuntimeMode.shouldStart(environment: [:]))
    }

    @Test func uiTestModeRendersSurfaceWithoutStartingLiveRuntime() {
        let environment = ["XCTestConfigurationFilePath": "/tmp/ui-tests.xctestconfiguration"]
        let arguments = ["SensorSynthFM", SensorSynthFMRuntimeMode.uiTestingLaunchArgument]

        #expect(SensorSynthFMRuntimeMode.isUITesting(arguments: arguments))
        #expect(SensorSynthFMRuntimeMode.shouldRenderSurface(environment: environment, arguments: arguments))
        #expect(!SensorSynthFMRuntimeMode.shouldStartLiveRuntime(environment: environment, arguments: arguments))
        #expect(!SensorSynthFMRuntimeMode.shouldStartLiveRuntime(environment: [:], arguments: arguments))
    }
    @Test func nativeNoteEntryMapsEightLanesAndBoundaries() {
        let mapper = PitchMapper()
        #expect(mapper.target(normalizedY: 0, mode: .quantized).midiNote == 60)
        #expect(mapper.target(normalizedY: 0.124, mode: .quantized).midiNote == 60)
        #expect(mapper.target(normalizedY: 0.125, mode: .quantized).midiNote == 62)
        #expect(mapper.target(normalizedY: 0.999, mode: .quantized).midiNote == 72)
        #expect(mapper.target(normalizedY: 1, mode: .quantized).lane == 7)
    }

    @Test func nativeNoteEntryIgnoresHorizontalMotion() {
        let state = NoteEntryState()
        let started = state.beginTouch(id: "x", normalizedY: 0.24)
        let moved = state.moveTouch(id: "x", normalizedX: 0.99, normalizedY: 0.24)
        #expect(started?.target == moved?.target)
        #expect(PitchMapper.horizontalInvariant(normalizedY: 0.24, mode: .quantized))
    }

    @Test func nativeNoteEntryMapsFreehandAcrossOneOctave() {
        let mapper = PitchMapper()
        #expect(mapper.target(normalizedY: 0, mode: .freehand).midiNote == 60)
        #expect(mapper.target(normalizedY: 0.5, mode: .freehand).midiNote == 66)
        #expect(mapper.target(normalizedY: 1, mode: .freehand).midiNote == 72)
    }

    @Test func nativeNoteEntryClampsOctaveOffsetToTwoOctaves() {
        let state = NoteEntryState()
        state.setOctaveOffset(3)
        #expect(state.octaveOffset == 2)
        #expect(state.rangeLabel == "MIDI 84–96")
        state.setOctaveOffset(-3)
        #expect(state.octaveOffset == -2)
        #expect(state.rangeLabel == "MIDI 36–48")
    }

    @Test func nativeNoteEntryKeepsIdentityThroughMovementAndModeToggle() {
        let state = NoteEntryState()
        let started = state.beginTouch(id: "held", normalizedY: 0.2)
        state.setMode(.freehand)
        let moved = state.moveTouch(id: "held", normalizedX: 0.1, normalizedY: 0.7)
        #expect(started?.voiceID == moved?.voiceID)
        #expect(state.activeVoiceCount == 1)
        #expect(state.remapCount == 1)
    }

    @Test func nativeNoteEntryReleasesOnlyOneChordTouch() {
        let state = NoteEntryState()
        _ = state.beginTouch(id: "a", normalizedY: 0.1)
        _ = state.beginTouch(id: "b", normalizedY: 0.3)
        _ = state.beginTouch(id: "c", normalizedY: 0.5)
        let released = state.endTouch(id: "b")
        #expect(released?.id == "b")
        #expect(state.activeVoiceCount == 2)
        #expect(state.touches["a"] != nil)
        #expect(state.touches["c"] != nil)
    }

    @Test func nativeNoteEntryCancellationAndReleaseAllRecover() {
        let state = NoteEntryState()
        _ = state.beginTouch(id: "a", normalizedY: 0.1)
        _ = state.beginTouch(id: "b", normalizedY: 0.3)
        let cancelled = state.cancelAll(reason: "window lost")
        #expect(cancelled.count == 2)
        #expect(state.activeVoiceCount == 0)
        #expect(state.lastRecoveryReason == "window lost")
        _ = state.beginTouch(id: "recovered", normalizedY: 0.5)
        #expect(state.activeVoiceCount == 1)
    }

    @Test func nativeNoteEntryUsesNamedQuantizedHysteresisThreshold() {
        let mapper = PitchMapper()
        let threshold = 1.0 / 8.0 * PitchMapper.quantizedHysteresis
        #expect(mapper.quantizedLane(normalizedY: 1.0 / 8.0 + threshold * 0.9, currentLane: 0) == 0)
        #expect(mapper.quantizedLane(normalizedY: 1.0 / 8.0 + threshold * 1.1, currentLane: 0) == 1)
    }

    @Test func nativeNoteEntryAllocatesFiveFloorAndTenVoiceTarget() {
        let state = NoteEntryState()
        for index in 0..<NoteEntryState.targetVoiceCapacity {
            _ = state.beginTouch(id: "touch-\(index)", normalizedY: Double(index) / 10.0)
        }
        #expect(NoteEntryState.stableVoiceFloor == 5)
        #expect(state.activeVoiceCount == 10)
        #expect(state.beginTouch(id: "overflow", normalizedY: 0.5) == nil)
    }

    @Test func passiveSensorUpdatesCannotCreateNotesOrChangeTouchPitch() {
        let state = NoteEntryState()
        let touch = state.beginTouch(id: "manual", normalizedY: 0.25)
        let originalPitch = touch?.pitch
        state.applyPassiveSensorTimbre(0.8)
        #expect(state.activeVoiceCount == 1)
        #expect(state.sensorTimbreInfluence == 0.8)
        #expect(state.touches["manual"]?.pitch == originalPitch)
    }

    @Test func globalTimbreChangesDoNotOwnTouchPitch() {
        let state = NoteEntryState()
        let first = state.beginTouch(id: "first", normalizedY: 0.1)
        let second = state.beginTouch(id: "second", normalizedY: 0.6)
        let pitches = state.activeTouches.map(\.pitch)
        state.applyPassiveSensorTimbre(0.5)
        #expect(first?.pitch == pitches[0])
        #expect(second?.pitch == pitches[1])
        #expect(state.activeTouches.map(\.pitch) == pitches)
        #expect(state.sensorTimbreInfluence == 0.5)
    }

}