#!/usr/bin/env python3
"""Source contracts for real-time handoff and hosted-test runtime isolation."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
SENSOR_MANAGER = ROOT / "SensorSynthFM" / "SensorManager.swift"
APP = ROOT / "SensorSynthFM" / "SensorSynthFMApp.swift"
VIEW = ROOT / "SensorSynthFM" / "SensorFMTestView.swift"
SWIFT_TESTS = ROOT / "SensorSynthFMTests" / "SensorSynthFMTests.swift"


class RuntimeSafetyContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.sensor_source = SENSOR_MANAGER.read_text(encoding="utf-8")
        cls.app_source = APP.read_text(encoding="utf-8")
        cls.view_source = VIEW.read_text(encoding="utf-8")
        cls.swift_test_source = SWIFT_TESTS.read_text(encoding="utf-8")

    def test_audio_handoff_uses_native_atomics_not_plain_float_pointers(self) -> None:
        self.assertIn("import Synchronization", self.sensor_source)
        self.assertIn("struct AudioSampleSnapshot: ~Copyable, Sendable", self.sensor_source)
        self.assertGreaterEqual(self.sensor_source.count("Atomic<Float>"), 5)
        self.assertNotRegex(
            self.sensor_source,
            r"atomic[A-Za-z]+:\s*UnsafeMutablePointer<Float>",
        )
        self.assertNotIn("allocateAtomicBuffers", self.sensor_source)
        self.assertNotIn("freeAtomicBuffers", self.sensor_source)
        self.assertRegex(self.sensor_source, r"sampleSnapshot\.store\(")
        self.assertRegex(self.sensor_source, r"sampleSnapshot\.load\(\)")

    def test_hosted_unit_tests_do_not_construct_the_live_audio_view(self) -> None:
        compact = re.sub(r"\s+", " ", self.app_source)
        self.assertIn("enum SensorSynthFMRuntimeMode", self.app_source)
        self.assertIn('environment["XCTestConfigurationFilePath"]', self.app_source)
        self.assertRegex(
            compact,
            r"if SensorSynthFMRuntimeMode\.shouldRenderSurface\(environment: ProcessInfo\.processInfo\.environment, arguments: ProcessInfo\.processInfo\.arguments\) \{ SensorFMTestView\(startLiveRuntime: SensorSynthFMRuntimeMode\.shouldStartLiveRuntime\(environment: ProcessInfo\.processInfo\.environment, arguments: ProcessInfo\.processInfo\.arguments\)\) \} else \{ Color\.clear \}",
        )

    def test_ui_test_launch_argument_renders_surface_without_live_runtime(self) -> None:
        self.assertIn('static let uiTestingLaunchArgument = "-ui-testing"', self.app_source)
        self.assertIn("arguments.contains(uiTestingLaunchArgument)", self.app_source)
        self.assertIn("static func shouldRenderSurface(environment: [String: String], arguments: [String])", self.app_source)
        self.assertIn("static func shouldStartLiveRuntime(environment: [String: String], arguments: [String])", self.app_source)
        self.assertIn("guard startLiveRuntime else { return }", self.view_source)

    def test_swift_behavior_tests_cover_both_blockers(self) -> None:
        self.assertIn("audioSampleSnapshotRoundTripsAtomically", self.swift_test_source)
        self.assertIn("runtimeIsSuppressedForHostedUnitTests", self.swift_test_source)
        self.assertIn("runtimeStartsOutsideHostedUnitTests", self.swift_test_source)


if __name__ == "__main__":
    unittest.main()
