//
//  SensorSynthFMTests.swift
//  SensorSynthFMTests
//
//  Created by nomad james on 2/16/26.
//

import Foundation
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
        #expect(mapper.target(normalizedY: 0, mode: .quantized).midiNote == 72)
        #expect(mapper.target(normalizedY: 0.124, mode: .quantized).midiNote == 72)
        #expect(mapper.target(normalizedY: 0.125, mode: .quantized).midiNote == 71)
        #expect(mapper.target(normalizedY: 0.999, mode: .quantized).midiNote == 60)
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
        #expect(mapper.target(normalizedY: 0, mode: .freehand).midiNote == 72)
        #expect(mapper.target(normalizedY: 0.5, mode: .freehand).midiNote == 66)
        #expect(mapper.target(normalizedY: 1, mode: .freehand).midiNote == 60)
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

    @Test func touchIdentifierAllocatorNeverReusesIdentifiers() {
        var allocator = TouchIdentifierAllocator()
        let ids = (0..<3).map { _ in allocator.allocate() }
        #expect(ids == ["touch-1", "touch-2", "touch-3"])
        #expect(Set(ids).count == ids.count)
    }

    @Test func sensorBridgePerformanceModeUsesTimbreOnlySinkPolicy() {
        let sink = RecordingSensorFMParameterSink()
        let bridge = SensorFMBridge(parameterSink: sink)
        bridge.setBaseValue(880, for: .carrierFrequency)
        #expect(sink.carrierFrequency == 880)

        sink.carrierFrequency = 321
        bridge.performanceMode = true
        #expect(sink.carrierFrequency == 321)
        #expect(sink.modulatorRatio == bridge.outputValue(for: .modulatorRatio))
        #expect(sink.modulationIndex == bridge.outputValue(for: .modulationIndex))
        #expect(sink.amplitude == bridge.outputValue(for: .amplitude))

        bridge.performanceMode = false
        #expect(sink.carrierFrequency == bridge.outputValue(for: .carrierFrequency))
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

    @Test func nativeNoteEntryHoldTransfersFinalPitchAndKeepsVoice() {
        let state = NoteEntryState()
        state.setHoldEnabled(true)
        let touch = state.beginTouch(id: "hold", normalizedX: 0.25, normalizedY: 0.9)
        _ = state.endTouch(id: "hold")

        #expect(state.activeVoiceCount == 0)
        #expect(state.heldNotes.count == 1)
        #expect(state.heldNotes.values.first?.target == touch?.target)
        #expect(state.isVoiceHeld(touch?.voiceID ?? -1))
    }

    @Test func nativeNoteEntryHoldDeduplicatesAndRetriggersHeldPitch() {
        let state = NoteEntryState()
        state.setHoldEnabled(true)
        _ = state.beginTouch(id: "first", normalizedY: 0.9)
        _ = state.endTouch(id: "first")
        let heldVoice = state.heldNotes.values.first?.voiceID
        let retrigger = state.beginTouch(id: "second", normalizedX: 0.8, normalizedY: 0.9)
        _ = state.endTouch(id: "second")

        #expect(state.heldNotes.count == 1)
        #expect(state.heldNotes.values.first?.voiceID == heldVoice)
        #expect(retrigger?.startedOnHeldPitch == true)
        #expect(retrigger?.voiceID == heldVoice)
    }

    @Test func nativeNoteEntrySecondTouchOnHeldPitchUsesIndependentVoice() {
        let state = NoteEntryState()
        state.setHoldEnabled(true)
        _ = state.beginTouch(id: "seed", normalizedY: 0.9)
        _ = state.endTouch(id: "seed")
        let heldVoice = state.heldNotes.values.first?.voiceID
        let first = state.beginTouch(id: "first", normalizedY: 0.9)
        let second = state.beginTouch(id: "second", normalizedY: 0.9)

        #expect(first?.voiceID == heldVoice)
        #expect(second?.voiceID != heldVoice)
        #expect(second?.voiceID != first?.voiceID)
    }

    @Test func nativeNoteEntryDuplicateActivePitchKeepsFirstHeldOwner() {
        let state = NoteEntryState()
        state.setHoldEnabled(true)
        let first = state.beginTouch(id: "first", normalizedY: 0.9)
        let second = state.beginTouch(id: "second", normalizedY: 0.9)
        _ = state.endTouch(id: "first")
        _ = state.endTouch(id: "second")

        #expect(state.heldNotes.count == 1)
        #expect(state.heldNotes.values.first?.voiceID == first?.voiceID)
        #expect(!state.isVoiceHeld(second?.voiceID ?? -1))
    }

    @Test func nativeNoteEntryMappingChangesRemapHeldPitchAtStableMarker() {
        let state = NoteEntryState()
        state.setHoldEnabled(true)
        _ = state.beginTouch(id: "held", normalizedX: 0.2, normalizedY: 0.2)
        _ = state.endTouch(id: "held")
        let markerY = state.heldNotes.values.first?.normalizedY
        state.setMode(.freehand)
        state.setOctaveOffset(1)

        #expect(state.heldNotes.values.first?.normalizedY == markerY)
        #expect(state.heldNotes.values.first?.target.midiNote == 81.6)
        #expect(state.removeHeldPitch(normalizedY: markerY ?? 1) != nil)
    }

    @Test func nativeNoteEntryHeldDragThroughOccupiedPitchKeepsOtherOwner() {
        let state = NoteEntryState()
        state.setHoldEnabled(true)
        let a = state.beginTouch(id: "a", normalizedY: 0.9)
        _ = state.endTouch(id: "a")
        let b = state.beginTouch(id: "b", normalizedY: 0.7)
        _ = state.endTouch(id: "b")
        let bPitch = b?.pitch

        _ = state.beginTouch(id: "drag-a", normalizedY: 0.9)
        _ = state.moveTouch(id: "drag-a", normalizedX: 0.5, normalizedY: 0.7)
        _ = state.moveTouch(id: "drag-a", normalizedX: 0.5, normalizedY: 0.45)
        _ = state.endTouch(id: "drag-a")

        #expect(state.heldNotes.count == 2)
        #expect(state.heldNotes.values.contains { $0.voiceID == b?.voiceID && $0.pitch == bPitch })
        #expect(state.heldNotes.values.contains { $0.voiceID == a?.voiceID && $0.pitch != bPitch })
    }

    @Test func nativeNoteEntryHeldOwnerSurvivesMappingChangeThenDrag() {
        let state = NoteEntryState()
        state.setHoldEnabled(true)
        let seed = state.beginTouch(id: "seed", normalizedY: 0.9)
        _ = state.endTouch(id: "seed")
        _ = state.beginTouch(id: "drag", normalizedY: 0.9)
        state.setMode(.freehand)
        state.setOctaveOffset(1)
        let moved = state.moveTouch(id: "drag", normalizedX: 0.5, normalizedY: 0.25)
        _ = state.endTouch(id: "drag")

        #expect(state.heldNotes.count == 1)
        #expect(state.heldNotes.values.first?.voiceID == seed?.voiceID)
        #expect(state.heldNotes.values.first?.target == moved?.target)
    }

    @Test func nativeNoteEntryHoldOffPreservesActiveTouchOwnership() {
        let state = NoteEntryState()
        state.setHoldEnabled(true)
        _ = state.beginTouch(id: "first", normalizedY: 0.9)
        _ = state.endTouch(id: "first")
        let active = state.beginTouch(id: "active", normalizedY: 0.9)
        let releasedHoldOwners = state.setHoldEnabled(false)

        #expect(releasedHoldOwners.count == 1)
        #expect(active?.voiceID == releasedHoldOwners.first?.voiceID)
        #expect(state.isVoiceTouched(active?.voiceID ?? -1))
        #expect(!state.isVoiceHeld(active?.voiceID ?? -1))
    }

    @Test func nativeNoteEntryReleasedIndicatorTracksEnvelopeOpacity() {
        let start = Date(timeIntervalSince1970: 100)
        let indicator = ReleasedNoteIndicator(
            id: "released",
            voiceID: 0,
            normalizedX: 0.5,
            normalizedY: 0.5,
            target: PitchTarget(midiNote: 60, lane: 7),
            releasedAt: start,
            lifetimeMilliseconds: 180
        )

        #expect(indicator.opacity(at: start) == 1)
        #expect(abs(indicator.opacity(at: start.addingTimeInterval(0.09)) - 0.5) < 0.000_001)
        #expect(indicator.opacity(at: start.addingTimeInterval(0.18)) < 0.000_001)
    }

    @Test func physicalReviewFeedbackTuningUsesReadableHaloAndReleaseLifetime() {
        #expect(NoteEntryState.releasedIndicatorLifetimeMilliseconds == 350)
        #expect(FMEngine.releaseEnvelopeMilliseconds == 350)
    }

    @Test func nativeNoteEntryDragMovesHeldOwnershipAndReleaseAllClearsIt() {
        let state = NoteEntryState()
        state.setHoldEnabled(true)
        _ = state.beginTouch(id: "first", normalizedY: 0.9)
        _ = state.endTouch(id: "first")
        let oldPitch = state.heldNotes.values.first?.pitch
        _ = state.beginTouch(id: "drag", normalizedX: 0.2, normalizedY: 0.9)
        _ = state.moveTouch(id: "drag", normalizedX: 0.7, normalizedY: 0.2)
        _ = state.endTouch(id: "drag")

        #expect(state.heldNotes.count == 1)
        #expect(state.heldNotes.values.first?.pitch != oldPitch)
        _ = state.releaseAll(reason: "test release all")
        #expect(state.heldNotes.isEmpty)
        #expect(state.activeVoiceCount == 0)
    }

    @Test func nativeNoteEntryPitchFeedbackIncludesFrequencyAndFreehandCents() {
        let mapper = PitchMapper()
        let target = mapper.target(normalizedY: 7.0 / 12.0, mode: .freehand)
        let feedback = NoteFeedbackFormatter.feedback(for: target, mode: .freehand)

        #expect(feedback.noteName == "F4")
        #expect(feedback.frequencyText.contains("Hz"))
        #expect(feedback.centsText != nil)
    }
}

private final class RecordingSensorFMParameterSink: SensorFMParameterSink {
    var carrierFrequency = 440.0
    var modulatorRatio = 1.0
    var modulationIndex = 1.0
    var amplitude = 0.5
}