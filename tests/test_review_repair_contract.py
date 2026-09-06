#!/usr/bin/env python3
"""Linux contracts for the bounded independent-review repair pass."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
SWIFT = ROOT / "SensorSynthFM"
UI_TESTS = ROOT / "SensorSynthFMUITests"


class ReviewRepairContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.model = (SWIFT / "NoteEntryModel.swift").read_text(encoding="utf-8")
        cls.surface = (SWIFT / "PerformanceNoteSurface.swift").read_text(encoding="utf-8")
        cls.engine = (SWIFT / "FMEngine.swift").read_text(encoding="utf-8")
        cls.bridge = (SWIFT / "SensorFMBridge.swift").read_text(encoding="utf-8")
        cls.view = (SWIFT / "SensorFMTestView.swift").read_text(encoding="utf-8")
        cls.swift_tests = (ROOT / "SensorSynthFMTests" / "SensorSynthFMTests.swift").read_text(encoding="utf-8")
        cls.ui = (UI_TESTS / "SensorSynthFMUITests.swift").read_text(encoding="utf-8")
        cls.launch = (UI_TESTS / "SensorSynthFMUITestsLaunchTests.swift").read_text(encoding="utf-8")

    def test_touch_identity_is_monotonic_and_owned_by_object_identifier(self) -> None:
        self.assertIn("struct TouchIdentifierAllocator", self.model)
        self.assertIn("mutating func allocate()", self.model)
        self.assertIn("identifierAllocator.allocate()", self.surface)
        self.assertIn("[ObjectIdentifier: String]", self.surface)
        self.assertNotIn("ObjectIdentifier(touch).hashValue", self.surface)
        self.assertIn("touchIdentifierAllocatorNeverReusesIdentifiers", self.swift_tests)

    def test_pitch_remap_uses_a_real_clamped_parameter_ramp(self) -> None:
        self.assertIn("voice.oscillator.$baseFrequency.ramp(", self.engine)
        self.assertRegex(
            self.engine,
            r"ramp\(\s*to: AUValue\(voice\.frequency\),\s*duration:",
        )
        ramp_start = self.engine.index("func setFrequency(")
        ramp_end = self.engine.index("func releaseAllVoices", ramp_start)
        ramp_body = self.engine[ramp_start:ramp_end]
        self.assertNotIn("voice.oscillator.baseFrequency =", ramp_body)
        self.assertRegex(ramp_body, r"isFinite|validatedRamp")
        self.assertIn("lastPitchRampMilliseconds", self.swift_tests + self.engine)

    def test_navigation_uses_explicit_voice_safe_transitions(self) -> None:
        self.assertIn("private func enterMatrixMode()", self.view)
        self.assertIn("private func returnToPerformanceMode()", self.view)
        self.assertIn('releaseAllTouches(reason: "entering matrix")', self.view)
        self.assertIn('releaseAllTouches(reason: "returning to performance")', self.view)
        self.assertIn("engine.noteOff()", self.view)
        self.assertIn("enterMatrixMode()", self.view)
        self.assertIn("returnToPerformanceMode()", self.view)
        self.assertNotIn(".onChange(of: showMatrix)", self.view)

    def test_accepted_matrix_regressions_are_preserved_alongside_performance_tests(self) -> None:
        for name in (
            "testNeutralRouteCanActivateAndBeRemovedWithoutCollapsingEditor",
            "testMatrixReachesOffscreenSourceAndKeepsContextQueryable",
            "testDefaultSurfaceIsPerformance",
        ):
            self.assertIn(name, self.ui)
        self.assertIn('performance.note.surface.container', self.ui)
        self.assertIn('performance.note.surface.container', self.launch)
        self.assertIn('modulation.matrix.viewport', self.ui)
        self.assertIn("private func openMatrix()", self.ui)
        for name in (
            "testNeutralRouteCanActivateAndBeRemovedWithoutCollapsingEditor",
            "testMatrixReachesOffscreenSourceAndKeepsContextQueryable",
        ):
            start = self.ui.index(f"func {name}")
            end = self.ui.find("@MainActor", start + 1)
            body = self.ui[start : len(self.ui) if end == -1 else end]
            self.assertIn("openMatrix()", body)

    def test_performance_ui_tests_assert_behavior_and_use_visible_container_anchor(self) -> None:
        self.assertIn('"VOICES 0/10"', self.ui)
        self.assertIn('"FREEHAND"', self.ui)
        self.assertIn('"QUANTIZED"', self.ui)
        self.assertIn('"MIDI 72–84"', self.ui)
        self.assertIn('"MIDI 60–72"', self.ui)
        for evidence in ("TOUCH B1 M", "R1", "PITCH CHANGED YES"):
            self.assertIn(evidence, self.ui)
        self.assertIn("performance.touch.lifecycle", self.view)
        self.assertIn("performance.pitch.mode", self.view)
        self.assertIn("performance.pitch.range", self.view)
        lifecycle_test = self.ui[self.ui.index("func testSingleTouchPressDragReleaseLifecycle"):]
        self.assertIn("performance.note.surface.container", lifecycle_test)
        self.assertIn("waitForValueContaining", lifecycle_test)
        self.assertNotIn("testReleaseTouchesReturnsToZeroActiveVoices", self.ui)

    def test_sensor_bridge_integration_exercises_production_mode_policy(self) -> None:
        self.assertIn("protocol SensorFMParameterSink: AnyObject", self.bridge)
        self.assertIn("parameterSink", self.bridge)
        self.assertIn("init(parameterSink:", self.bridge)
        self.assertIn("extension FMEngine: SensorFMParameterSink", self.engine)
        self.assertIn("sensorBridgePerformanceModeUsesTimbreOnlySinkPolicy", self.swift_tests)
        self.assertNotRegex(self.bridge, r"noteOn|noteOff")
        self.assertIn("if performanceMode", self.bridge)
        self.assertIn("engine.modulatorRatio", self.bridge)
        self.assertIn("engine.modulationIndex", self.bridge)
        self.assertIn("engine.amplitude", self.bridge)


if __name__ == "__main__":
    unittest.main()
