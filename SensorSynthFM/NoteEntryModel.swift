// NoteEntryModel.swift
// SensorSynthFM
//
// Pure, deterministic note-entry state. UIKit only supplies touch identity and
// normalized coordinates. Audio realization is kept in FMEngine.

import Foundation
import Observation

/// Allocates process-local touch identifiers without deriving identity from a hash.
/// The allocator never reuses an identifier, so released contacts cannot overlap a
/// later contact even if UIKit reuses an ObjectIdentifier.
public struct TouchIdentifierAllocator: Sendable {
    private var nextID: UInt64 = 0

    public init() {}

    public mutating func allocate() -> String {
        precondition(nextID < UInt64.max, "Touch identifier allocator exhausted")
        nextID += 1
        return "touch-\(nextID)"
    }
}

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

    /// Visual lane zero is the high edge. Lane seven is the low edge.
    public func midiNote(forLane lane: Int) -> Int {
        let boundedLane = min(max(lane, 0), 7)
        if boundedLane == 0 { return rootMIDINote + 12 }
        if boundedLane == 7 { return rootMIDINote }
        return rootMIDINote + degrees[7 - boundedLane]
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
                midiNote: Double(scale.rootMIDINote) + (1.0 - y) * Self.visibleOctaveSemitones,
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

        if y >= upperBoundary { return directLane }
        if y <= lowerBoundary { return directLane }
        return currentLane
    }

    public static func horizontalInvariant(normalizedY: Double, mode: PitchMode) -> Bool {
        let mapper = PitchMapper()
        return mapper.target(normalizedX: 0.1, normalizedY: normalizedY, mode: mode).midiNote
            == mapper.target(normalizedX: 0.9, normalizedY: normalizedY, mode: mode).midiNote
    }
}

public struct NoteFeedback: Equatable, Sendable {
    public let noteName: String
    public let frequencyText: String
    public let centsText: String?

    public var label: String {
        if let centsText { return "\(noteName) · \(frequencyText) · \(centsText)" }
        return "\(noteName) · \(frequencyText)"
    }
}

public enum NoteFeedbackFormatter {
    private static let noteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    public static func noteName(for midiNote: Double) -> String {
        let rounded = Int(midiNote.rounded())
        let octave = rounded / 12 - 1
        let index = ((rounded % 12) + 12) % 12
        return "\(noteNames[index])\(octave)"
    }

    public static func feedback(for target: PitchTarget, mode: PitchMode) -> NoteFeedback {
        let rounded = target.midiNote.rounded()
        let centsText = mode == .freehand ? String(format: "%+.0f cents", (target.midiNote - rounded) * 100) : nil
        return NoteFeedback(
            noteName: noteName(for: target.midiNote),
            frequencyText: String(format: "%.1f Hz", target.frequency),
            centsText: centsText
        )
    }
}

public struct NoteTouch: Equatable, Sendable, Identifiable {
    public let id: String
    public let voiceID: Int
    public var normalizedX: Double
    public var normalizedY: Double
    public var target: PitchTarget
    public let startedOnHeldPitch: Bool
    fileprivate var heldOwnershipID: String?

    public var pitch: Double { target.midiNote }
    public var lane: Int? { target.lane }
}

/// A single unattended owner. The dictionary in NoteEntryState is keyed by the
/// normalized MIDI pitch key, so there is one unattended owner per pitch and
/// duplicate held pitches cannot be created. Every active-touch release explicitly transfers ownership here when Hold is enabled.
public struct HeldNote: Equatable, Sendable, Identifiable {
    public let id: String
    public let voiceID: Int
    public let normalizedY: Double
    public var target: PitchTarget

    public var pitch: Double { target.midiNote }
}

public struct ReleasedNoteIndicator: Equatable, Sendable, Identifiable {
    public let id: String
    public let voiceID: Int
    public let normalizedX: Double
    public let normalizedY: Double
    public let target: PitchTarget
    public let releasedAt: Date
    public let lifetimeMilliseconds: Double

    public func opacity(at date: Date) -> Double {
        let elapsedMilliseconds = max(0, date.timeIntervalSince(releasedAt) * 1_000)
        return min(max(1 - elapsedMilliseconds / lifetimeMilliseconds, 0), 1)
    }
}

@Observable
public final class NoteEntryState {
    public static let stableVoiceFloor = 5
    public static let targetVoiceCapacity = 10
    public static let maxVoices = 10
    public static let hysteresisThreshold = PitchMapper.laneHysteresis
    public static let pitchRemapRampMilliseconds = 20.0
    public static let releasedIndicatorLifetimeMilliseconds = 180.0
    public static let heldSelectionToleranceNormalized = 1.0 / 16.0

    public private(set) var mode: PitchMode = .quantized
    public private(set) var octaveOffset = 0
    public private(set) var touches: [String: NoteTouch] = [:]
    public private(set) var heldNotes: [Int: HeldNote] = [:]
    public private(set) var releasedIndicators: [ReleasedNoteIndicator] = []
    public private(set) var isHoldEnabled = false
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

    public var activeAndHeldVoiceCount: Int {
        Set(touches.values.map(\.voiceID) + heldNotes.values.map(\.voiceID)).count
    }

    @discardableResult
    public func beginTouch(id: String, normalizedY: Double) -> NoteTouch? {
        beginTouch(id: id, normalizedX: 0.5, normalizedY: normalizedY)
    }

    @discardableResult
    public func beginTouch(id: String, normalizedX: Double, normalizedY: Double) -> NoteTouch? {
        guard touches[id] == nil, touches.count < Self.targetVoiceCapacity else { return nil }
        let boundedX = min(max(normalizedX, 0), 1)
        let boundedY = min(max(normalizedY, 0), 1)
        let target = targetForOctave(mapper.target(normalizedY: boundedY, mode: mode))
        let key = pitchKey(for: target)
        let heldMatch = heldNotes[key]
        let reusableHeldVoiceID = heldMatch.flatMap { held in
            isVoiceTouched(held.voiceID) ? nil : held.voiceID
        }
        guard let voiceID = reusableHeldVoiceID ?? firstFreeVoiceID() else { return nil }
        let touch = NoteTouch(
            id: id,
            voiceID: voiceID,
            normalizedX: boundedX,
            normalizedY: boundedY,
            target: target,
            startedOnHeldPitch: heldMatch != nil,
            heldOwnershipID: reusableHeldVoiceID == nil ? nil : heldMatch?.id
        )
        touches[id] = touch
        return touch
    }

    @discardableResult
    public func moveTouch(id: String, normalizedX: Double, normalizedY: Double) -> NoteTouch? {
        guard var touch = touches[id] else { return nil }
        touch.normalizedX = min(max(normalizedX, 0), 1)
        touch.normalizedY = min(max(normalizedY, 0), 1)
        let target = targetForOctave(mapper.target(
            normalizedY: touch.normalizedY,
            mode: mode,
            currentLane: touch.target.lane
        ))
        if let ownershipID = touch.heldOwnershipID {
            let newKey = pitchKey(for: target)
            if heldNotes[newKey]?.id != ownershipID {
                let retainedOwnership = moveHeldOwnership(
                    id: ownershipID,
                    to: newKey,
                    normalizedY: touch.normalizedY,
                    fallbackTarget: target
                )
                if !retainedOwnership {
                    touch.heldOwnershipID = nil
                }
            }
        }
        touch.target = target
        touches[id] = touch
        return touch
    }

    @discardableResult
    public func endTouch(id: String) -> NoteTouch? {
        guard let touch = touches.removeValue(forKey: id) else { return nil }
        if isHoldEnabled, touch.heldOwnershipID == nil {
            let key = pitchKey(for: touch.target)
            if heldNotes[key] == nil {
                // Transfer the final pitch to unattended ownership. Assignment is
                // deliberate: one owner per pitch, even after a merge.
                heldNotes[key] = HeldNote(
                    id: "held-\(touch.voiceID)-\(key)",
                    voiceID: touch.voiceID,
                    normalizedY: touch.normalizedY,
                    target: touch.target
                )
            }
        }
        if !isVoiceHeld(touch.voiceID) {
            releasedIndicators.append(ReleasedNoteIndicator(
                id: "released-\(touch.voiceID)-\(releasedIndicators.count)",
                voiceID: touch.voiceID,
                normalizedX: touch.normalizedX,
                normalizedY: touch.normalizedY,
                target: touch.target,
                releasedAt: Date(),
                lifetimeMilliseconds: Self.releasedIndicatorLifetimeMilliseconds
            ))
        }
        return touch
    }

    @discardableResult
    public func releaseAll(reason: String = "manual release") -> [NoteTouch] {
        let released = activeTouches
        touches.removeAll(keepingCapacity: true)
        heldNotes.removeAll(keepingCapacity: true)
        releasedIndicators.removeAll(keepingCapacity: true)
        lastRecoveryReason = reason
        return released
    }

    @discardableResult
    public func cancelAll(reason: String = "touch cancellation") -> [NoteTouch] {
        releaseAll(reason: reason)
    }

    @discardableResult
    public func setHoldEnabled(_ enabled: Bool) -> [HeldNote] {
        guard isHoldEnabled != enabled else { return [] }
        isHoldEnabled = enabled
        guard !enabled else { return [] }
        let released = Array(heldNotes.values)
        heldNotes.removeAll(keepingCapacity: true)
        return released
    }

    @discardableResult
    public func toggleHold() -> [HeldNote] {
        setHoldEnabled(!isHoldEnabled)
    }

    /// Used by the smallest native press-and-select interaction on the Hold rail.
    @discardableResult
    public func removeHeldPitch(normalizedY: Double) -> HeldNote? {
        let boundedY = min(max(normalizedY, 0), 1)
        guard let match = heldNotes.min(by: {
            abs($0.value.normalizedY - boundedY) < abs($1.value.normalizedY - boundedY)
        }), abs(match.value.normalizedY - boundedY) <= Self.heldSelectionToleranceNormalized else {
            return nil
        }
        return heldNotes.removeValue(forKey: match.key)
    }

    @discardableResult
    public func removeHeldNote(id: String) -> HeldNote? {
        guard let match = heldNotes.first(where: { $0.value.id == id }) else { return nil }
        return heldNotes.removeValue(forKey: match.key)
    }

    public func isVoiceHeld(_ voiceID: Int) -> Bool {
        heldNotes.values.contains { $0.voiceID == voiceID }
    }

    public func isVoiceTouched(_ voiceID: Int) -> Bool {
        touches.values.contains { $0.voiceID == voiceID }
    }

    public func removeReleasedIndicator(id: String) {
        releasedIndicators.removeAll { $0.id == id }
    }

    @discardableResult
    public func setMode(_ newMode: PitchMode) -> [HeldNote] {
        guard mode != newMode else { return [] }
        mode = newMode
        for id in Array(touches.keys) {
            guard var touch = touches[id] else { continue }
            touch.target = targetForOctave(mapper.target(normalizedY: touch.normalizedY, mode: mode))
            touches[id] = touch
        }
        remapCount += 1
        return remapHeldNotes()
    }

    /// Sensor input is a timbral underlay only. It never edits touch targets.
    public func applyPassiveSensorTimbre(_ influence: Double) {
        sensorTimbreInfluence = min(max(influence, 0), 1)
    }

    @discardableResult
    public func setOctaveOffset(_ offset: Int) -> [HeldNote] {
        let boundedOffset = min(max(offset, -2), 2)
        guard octaveOffset != boundedOffset else { return [] }
        octaveOffset = boundedOffset
        for id in Array(touches.keys) {
            guard var touch = touches[id] else { continue }
            touch.target = targetForOctave(
                mapper.target(normalizedY: touch.normalizedY, mode: mode, currentLane: touch.target.lane)
            )
            touches[id] = touch
        }
        return remapHeldNotes()
    }

    private func firstFreeVoiceID() -> Int? {
        let used = Set(touches.values.map(\.voiceID) + heldNotes.values.map(\.voiceID))
        return (0..<Self.targetVoiceCapacity).first { !used.contains($0) }
    }

    private func pitchKey(for target: PitchTarget) -> Int {
        Int((target.midiNote * 1_000_000).rounded())
    }

    @discardableResult
    private func moveHeldOwnership(
        id ownershipID: String,
        to newKey: Int,
        normalizedY: Double,
        fallbackTarget: PitchTarget
    ) -> Bool {
        guard let source = heldNotes.first(where: { $0.value.id == ownershipID }) else { return false }
        if let destination = heldNotes[newKey], destination.id != ownershipID {
            heldNotes.removeValue(forKey: source.key)
            return false
        }
        heldNotes.removeValue(forKey: source.key)
        heldNotes[newKey] = HeldNote(
            id: source.value.id,
            voiceID: source.value.voiceID,
            normalizedY: normalizedY,
            target: fallbackTarget
        )
        return true
    }

    private func remapHeldNotes() -> [HeldNote] {
        var remapped: [Int: HeldNote] = [:]
        var displaced: [HeldNote] = []
        for held in heldNotes.values.sorted(by: { $0.voiceID < $1.voiceID }) {
            let target = targetForOctave(mapper.target(normalizedY: held.normalizedY, mode: mode))
            let key = pitchKey(for: target)
            if remapped[key] == nil {
                remapped[key] = HeldNote(
                    id: held.id,
                    voiceID: held.voiceID,
                    normalizedY: held.normalizedY,
                    target: target
                )
            } else {
                displaced.append(held)
            }
        }
        heldNotes = remapped
        return displaced
    }

    private func targetForOctave(_ target: PitchTarget) -> PitchTarget {
        guard octaveOffset != 0 else { return target }
        return PitchTarget(midiNote: target.midiNote + Double(octaveOffset * 12), lane: target.lane)
    }
}
