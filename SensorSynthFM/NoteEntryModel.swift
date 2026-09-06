// NoteEntryModel.swift
// SensorSynthFM
//
// Pure, deterministic note-entry state. UIKit only supplies touch identity and
// normalised coordinates. Audio realization is kept in FMEngine.

import Foundation
import Observation

public enum PitchMode: String, CaseIterable, Sendable {
    case quantized
    case freehand
}

public struct ScaleDefinition: Equatable, Sendable {
    public let rootMIDINote: Int
    public let degrees: [Int]

    public init(rootMIDINote: Int = 60, degrees: [Int] = [0, 2, 4, 5, 7, 9, 11]) {
        precondition(degrees.count == 7, "The first slice accepts seven-degree scales only")
        self.rootMIDINote = rootMIDINote
        self.degrees = degrees
    }

    public static let cMajor = ScaleDefinition()

    public func midiNote(forLane lane: Int) -> Int {
        let boundedLane = min(max(lane, 0), 7)
        if boundedLane == 7 { return rootMIDINote + 12 }
        return rootMIDINote + degrees[boundedLane]
    }
}

public struct PitchTarget: Equatable, Sendable {
    public let midiNote: Double
    public let frequency: Double
    public let lane: Int?

    public init(midiNote: Double, lane: Int?) {
        self.midiNote = midiNote
        self.frequency = 440.0 * pow(2.0, (midiNote - 69.0) / 12.0)
        self.lane = lane
    }
}

public struct PitchMapper: Sendable {
    public static let laneCount = 8
    public static let laneHysteresis = 0.15
    public static let quantizedHysteresis = laneHysteresis
    public static let visibleOctaveSemitones = 12.0

    public let scale: ScaleDefinition

    public init(scale: ScaleDefinition = .cMajor) {
        self.scale = scale
    }

    public func target(normalizedY: Double, mode: PitchMode, currentLane: Int? = nil) -> PitchTarget {
        let y = min(max(normalizedY, 0), 1)
        switch mode {
        case .freehand:
            return PitchTarget(
                midiNote: Double(scale.rootMIDINote) + y * Self.visibleOctaveSemitones,
                lane: nil
            )
        case .quantized:
            let lane = quantizedLane(normalizedY: y, currentLane: currentLane)
            return PitchTarget(midiNote: Double(scale.midiNote(forLane: lane)), lane: lane)
        }
    }

    public func target(normalizedX _: Double, normalizedY: Double, mode: PitchMode, currentLane: Int? = nil) -> PitchTarget {
        target(normalizedY: normalizedY, mode: mode, currentLane: currentLane)
    }

    public func quantizedLane(normalizedY: Double, currentLane: Int? = nil) -> Int {
        let y = min(max(normalizedY, 0), 1)
        let directLane = min(Self.laneCount - 1, Int(y * Double(Self.laneCount)))
        guard let currentLane, (0..<Self.laneCount).contains(currentLane) else {
            return directLane
        }

        let laneHeight = 1.0 / Double(Self.laneCount)
        let penetration = laneHeight * Self.laneHysteresis
        let upperBoundary = Double(currentLane + 1) * laneHeight + penetration
        let lowerBoundary = Double(currentLane) * laneHeight - penetration

        if y >= upperBoundary {
            return directLane
        }
        if y <= lowerBoundary {
            return directLane
        }
        return currentLane
    }

    public static func horizontalInvariant(normalizedY: Double, mode: PitchMode) -> Bool {
        let mapper = PitchMapper()
        return mapper.target(normalizedX: 0.1, normalizedY: normalizedY, mode: mode).midiNote
            == mapper.target(normalizedX: 0.9, normalizedY: normalizedY, mode: mode).midiNote
    }
}

public struct NoteTouch: Equatable, Sendable, Identifiable {
    public let id: String
    public let voiceID: Int
    public var normalizedY: Double
    public var target: PitchTarget

    public var pitch: Double { target.midiNote }
    public var lane: Int? { target.lane }
}

@Observable
public final class NoteEntryState {
    public static let stableVoiceFloor = 5
    public static let targetVoiceCapacity = 10
    public static let maxVoices = 10
    public static let hysteresisThreshold = PitchMapper.laneHysteresis
    public static let pitchRemapRampMilliseconds = 20.0

    public private(set) var mode: PitchMode = .quantized
    public private(set) var octaveOffset = 0
    public private(set) var touches: [String: NoteTouch] = [:]
    public private(set) var lastRecoveryReason: String?
    public private(set) var remapCount = 0
    public private(set) var sensorTimbreInfluence = 0.0

    public let scale: ScaleDefinition
    public let mapper: PitchMapper

    public init(scale: ScaleDefinition = .cMajor) {
        self.scale = scale
        self.mapper = PitchMapper(scale: scale)
    }

    public var activeTouches: [NoteTouch] {
        touches.values.sorted { $0.voiceID < $1.voiceID }
    }

    public var activeVoiceCount: Int { touches.count }
    public var isPolyphonic: Bool { activeVoiceCount > 1 }
    public var rangeLabel: String {
        let root = scale.rootMIDINote + octaveOffset * 12
        return "MIDI \(root)–\(root + 12)"
    }

    @discardableResult
    public func beginTouch(id: String, normalizedY: Double) -> NoteTouch? {
        guard touches[id] == nil, touches.count < Self.targetVoiceCapacity else { return nil }
        let voiceID = firstFreeVoiceID()
        let target = mapper.target(normalizedY: normalizedY, mode: mode)
        let touch = NoteTouch(
            id: id,
            voiceID: voiceID,
            normalizedY: min(max(normalizedY, 0), 1),
            target: targetForOctave(target)
        )
        touches[id] = touch
        return touch
    }

    @discardableResult
    public func moveTouch(id: String, normalizedX _: Double, normalizedY: Double) -> NoteTouch? {
        guard var touch = touches[id] else { return nil }
        touch.normalizedY = min(max(normalizedY, 0), 1)
        let target = mapper.target(
            normalizedY: touch.normalizedY,
            mode: mode,
            currentLane: touch.target.lane
        )
        touch.target = targetForOctave(target)
        touches[id] = touch
        return touch
    }

    @discardableResult
    public func endTouch(id: String) -> NoteTouch? {
        touches.removeValue(forKey: id)
    }

    @discardableResult
    public func releaseAll(reason: String = "manual release") -> [NoteTouch] {
        let released = activeTouches
        touches.removeAll(keepingCapacity: true)
        lastRecoveryReason = reason
        return released
    }

    @discardableResult
    public func cancelAll(reason: String = "touch cancellation") -> [NoteTouch] {
        releaseAll(reason: reason)
    }

    public func setMode(_ newMode: PitchMode) {
        guard mode != newMode else { return }
        mode = newMode
        for id in Array(touches.keys) {
            guard var touch = touches[id] else { continue }
            touch.target = targetForOctave(mapper.target(normalizedY: touch.normalizedY, mode: mode))
            touches[id] = touch
        }
        remapCount += 1
    }

    /// Sensor input is a timbral underlay only. It never edits touch targets.
    public func applyPassiveSensorTimbre(_ influence: Double) {
        sensorTimbreInfluence = min(max(influence, 0), 1)
    }

    public func setOctaveOffset(_ offset: Int) {
        octaveOffset = min(max(offset, -2), 2)
        for id in Array(touches.keys) {
            guard var touch = touches[id] else { continue }
            touch.target = targetForOctave(
                mapper.target(normalizedY: touch.normalizedY, mode: mode, currentLane: touch.target.lane)
            )
            touches[id] = touch
        }
    }

    private func firstFreeVoiceID() -> Int {
        let used = Set(touches.values.map(\.voiceID))
        return (0..<Self.targetVoiceCapacity).first { !used.contains($0) } ?? 0
    }

    private func targetForOctave(_ target: PitchTarget) -> PitchTarget {
        guard octaveOffset != 0 else { return target }
        return PitchTarget(midiNote: target.midiNote + Double(octaveOffset * 12), lane: target.lane)
    }
}
