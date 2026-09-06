#!/usr/bin/env python3
"""Static contracts for the bounded native note-entry slice.

Swift/Xcode execution belongs on the Mac. These checks keep the Linux gate
useful by asserting that the native bridge, pure state model, and UI wiring
remain present and bounded.
"""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SWIFT = ROOT / "SensorSynthFM"


class NativeNoteEntryContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = (SWIFT / "NoteEntryModel.swift").read_text(encoding="utf-8")
        cls.surface = (SWIFT / "PerformanceNoteSurface.swift").read_text(encoding="utf-8")
        cls.engine = (SWIFT / "FMEngine.swift").read_text(encoding="utf-8")
        cls.view = (SWIFT / "SensorFMTestView.swift").read_text(encoding="utf-8")
        cls.ui = (ROOT / "SensorSynthFMUITests" / "SensorSynthFMUITests.swift").read_text(encoding="utf-8")

    def test_model_names_the_bounded_pitch_and_recovery_contract(self):
        for token in (
            "ScaleDefinition",
            "PitchMapper",
            "quantizedHysteresis",
            "PitchMode",
            "releaseAll",
            "cancelAll",
            "horizontalInvariant",
        ):
            self.assertIn(token, self.model)
        self.assertIn("static let maxVoices = 10", self.model)
        self.assertIn("static let stableVoiceFloor = 5", self.model)

    def test_native_multitouch_bridge_is_a_uiview_not_a_draggesture(self):
        self.assertIn("UIViewRepresentable", self.surface)
        self.assertIn("class NoteEntrySurfaceView: UIView", self.surface)
        self.assertIn("touchesBegan", self.surface)
        self.assertIn("touchesMoved", self.surface)
        self.assertIn("touchesEnded", self.surface)
        self.assertIn("touchesCancelled", self.surface)
        self.assertNotIn("DragGesture", self.surface)

    def test_ui_accessibility_exposes_native_surface_and_rail_children(self):
        self.assertIn('accessibilityIdentifier = "performance.note.surface"', self.surface)
        self.assertIn("isAccessibilityElement = true", self.surface)
        rail_start = self.view.index("private var controlRail")
        rail_end = self.view.index("private func railButton", rail_start)
        rail = self.view[rail_start:rail_end]
        self.assertIn(".accessibilityElement(children: .contain)", rail)

    def test_engine_has_fixed_voice_bank_and_legacy_api(self):
        self.assertIn("static let voiceCapacity = 10", self.engine)
        self.assertIn("voiceBank", self.engine)
        self.assertIn("func noteOn(frequency: Double? = nil)", self.engine)
        self.assertIn("func noteOff()", self.engine)
        self.assertIn("func noteOn(voiceID: Int, frequency: Double)", self.engine)
        self.assertIn("func noteOff(voiceID: Int)", self.engine)

    def test_performance_is_default_and_matrix_is_explicit(self):
        self.assertIn("performanceSurface", self.view)
        self.assertIn('accessibilityIdentifier("performance.note.surface")', self.view)
        self.assertIn('identifier: "performance.matrix"', self.view)
        self.assertIn("showMatrix", self.view)
        self.assertIn("if showMatrix", self.view)
        self.assertIn("matrixReturnBar", self.view)

    def test_rail_and_controls_have_stable_identifiers(self):
        for identifier in (
            "performance.pitch.quantized",
            "performance.pitch.freehand",
            "performance.octave.down",
            "performance.octave.up",
            "performance.release.touches",
            "performance.matrix",
            "performance.hand.left",
            "performance.hand.right",
            "performance.active.voice.count",
        ):
            self.assertIn(identifier, self.view)
        self.assertIn("if isLeftHanded", self.view)
        self.assertIn("controlRail", self.view)

    def test_ui_tests_cover_bounded_performance_paths(self):
        for name in (
            "testDefaultSurfaceIsPerformance",
            "testMatrixRoundTrip",
            "testPitchModeAndOctaveControls",
            "testReleaseTouches",
            "testSingleTouchPressDragReleaseLifecycle",
        ):
            self.assertIn(name, self.ui)


if __name__ == "__main__":
    unittest.main()
