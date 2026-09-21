#!/usr/bin/env python3
"""Static Linux contracts for the bounded Hold and note-feedback slice."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SWIFT = ROOT / "SensorSynthFM"


class HoldNoteFeedbackContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = (SWIFT / "NoteEntryModel.swift").read_text(encoding="utf-8")
        cls.surface = (SWIFT / "PerformanceNoteSurface.swift").read_text(encoding="utf-8")
        cls.view = (SWIFT / "SensorFMTestView.swift").read_text(encoding="utf-8")
        cls.swift_tests = (ROOT / "SensorSynthFMTests" / "SensorSynthFMTests.swift").read_text(encoding="utf-8")
        cls.ui_tests = (ROOT / "SensorSynthFMUITests" / "SensorSynthFMUITests.swift").read_text(encoding="utf-8")

    def test_model_has_explicit_active_and_unattended_hold_ownership(self):
        for token in (
            "struct HeldNote",
            "heldNotes",
            "isHoldEnabled",
            "setHoldEnabled",
            "isVoiceHeld",
            "removeHeldPitch",
            "normalizedX",
            "releasedIndicators",
        ):
            self.assertIn(token, self.model)
        self.assertIn("transfer", self.model)
        self.assertIn("one unattended owner per pitch", self.model)

    def test_touching_a_held_pitch_reuses_its_voice(self):
        self.assertIn("reusableHeldVoiceID", self.model)
        self.assertIn("isVoiceTouched(held.voiceID) ? nil : held.voiceID", self.model)
        self.assertIn("isVoiceTouched", self.model)
        self.assertIn("!noteState.isVoiceTouched(held.voiceID)", self.view)

    def test_duplicate_active_pitch_cannot_overwrite_or_orphan_a_held_voice(self):
        self.assertIn("heldNotes[key] == nil", self.model)
        for name in (
            "nativeNoteEntrySecondTouchOnHeldPitchUsesIndependentVoice",
            "nativeNoteEntryDuplicateActivePitchKeepsFirstHeldOwner",
        ):
            self.assertIn(name, self.swift_tests)

    def test_held_marker_mapping_stays_invertible_across_mapping_changes(self):
        self.assertIn("normalizedY", self.model[self.model.index("struct HeldNote"):])
        self.assertIn("remapHeldNotes", self.model)
        self.assertIn("held.normalizedY", self.view)
        self.assertIn("heldSelectionToleranceNormalized", self.model)

    def test_held_ownership_tracks_stable_identity_not_a_stale_pitch_key(self):
        self.assertIn("heldOwnershipID", self.model)
        self.assertNotIn("heldOwnershipKey", self.model)
        self.assertIn("id ownershipID: String", self.model)
        for name in (
            "nativeNoteEntryHeldDragThroughOccupiedPitchKeepsOtherOwner",
            "nativeNoteEntryHeldOwnerSurvivesMappingChangeThenDrag",
        ):
            self.assertIn(name, self.swift_tests)

    def test_sensor_updates_do_not_truncate_a_pending_release_ramp(self):
        engine = (SWIFT / "FMEngine.swift").read_text(encoding="utf-8")
        apply_parameters = engine[engine.index("private func applyParameters"):]
        self.assertIn("voice.releaseWorkItem == nil", apply_parameters)
        self.assertIn("pending release ramp", apply_parameters)

    def test_hold_modifier_selection_does_not_toggle_hold_off(self):
        self.assertIn("holdPressConsumed", self.view)
        self.assertIn("toggleHoldFromControl", self.view)
        self.assertIn("holdPressConsumed = true", self.view)
        self.assertIn("DispatchQueue.main.async", self.view)

    def test_hold_has_accessible_selective_removal_and_surface_guidance(self):
        self.assertIn("accessibilityLabel = \"Performance note surface\"", self.surface)
        self.assertIn("accessibilityHint =", self.surface)
        self.assertIn("accessibilityAction(named:", self.view)
        self.assertIn("removeHeldNote(id:", self.model)

    def test_released_indicator_fades_and_expires_individually(self):
        for token in ("releasedAt", "func opacity(at", "removeReleasedIndicator"):
            self.assertIn(token, self.model)
        self.assertIn("TimelineView", self.view)
        self.assertIn("indicator.opacity(at:", self.view)
        self.assertIn("removeReleasedIndicator(id:", self.view)

    def test_physical_review_tuning_keeps_feedback_visible(self):
        self.assertIn(".frame(width: 52, height: 52)", self.view)
        self.assertIn(
            "isLeftHanded ? min(100, width - 80) : max(width - 100, 80)",
            self.view,
        )
        self.assertIn("releasedIndicatorLifetimeMilliseconds = 350.0", self.model)
        engine = (SWIFT / "FMEngine.swift").read_text(encoding="utf-8")
        self.assertIn("releaseEnvelopeMilliseconds = 350.0", engine)

    def test_ipad_build_is_landscape_only(self):
        project = (ROOT / "SensorSynthFM.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
        expected = (
            'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = '
            '"UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";'
        )
        self.assertEqual(project.count(expected), 2)

    def test_pitch_mapping_is_high_at_top_and_freehand_is_continuous(self):
        self.assertIn("(1.0 - y)", self.model)
        self.assertIn("laneCount - 1", self.model)
        self.assertNotIn("Double(scale.rootMIDINote) + y * Self.visibleOctaveSemitones", self.model)
        for token in ("NoteFeedbackFormatter", "cents", "frequency", "noteName"):
            self.assertIn(token, self.model)

    def test_touch_bridge_captures_normalized_x_from_begin_and_move(self):
        self.assertIn("began(id: String, normalizedX: Double, normalizedY: Double)", self.surface)
        self.assertIn("normalizedX: normalizedX(for: touch)", self.surface)
        self.assertIn("normalizedX: Double", self.model)

    def test_surface_has_hold_accessibility_and_structural_indicators(self):
        for token in (
            'performance.hold',
            'HOLD',
            'performance.release.touches',
            'HELD',
            'RELEASED',
            'ACTIVE',
            'fixed pitch-edge',
            'isLeftHanded',
        ):
            self.assertIn(token, self.view)
        self.assertIn("holdControlIsPressed", self.view)
        self.assertIn("removeHeldPitch", self.view)

    def test_focused_swift_and_ui_tests_name_the_new_acceptance_paths(self):
        for name in (
            "nativeNoteEntryHoldTransfersFinalPitchAndKeepsVoice",
            "nativeNoteEntryHoldDeduplicatesAndRetriggersHeldPitch",
            "nativeNoteEntryDragMovesHeldOwnershipAndReleaseAllClearsIt",
            "nativeNoteEntryPitchFeedbackIncludesFrequencyAndFreehandCents",
            "testHoldControlAndReleasedFeedbackAreAccessible",
        ):
            self.assertIn(name, self.swift_tests + self.ui_tests)


if __name__ == "__main__":
    unittest.main()
