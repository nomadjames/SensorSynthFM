"""Source wiring regressions only; native PCM/UI remain the acceptance gates."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PhysicalRepairContractTests(unittest.TestCase):
    def test_all_native_envelope_assignments_use_stage_calibration(self):
        engine = (ROOT / "SensorSynthFM/FMEngine.swift").read_text()
        for stage, target in (("attack", "ampAttack"), ("decay", "ampDecay"), ("release", "ampRelease")):
            self.assertIn(f"EnvelopeStageTiming.{stage}(SensorModulationTarget.{target}.defaultValue)", engine)
            self.assertIn(f"EnvelopeStageTiming.{stage}(SensorModulationTarget.{target}.clamp({target}))", engine)
        self.assertIn("EnvelopeStageTiming.release(releaseSeconds)", engine)
        self.assertIn("releaseSeconds + Self.releaseCleanupSlackSeconds", engine)
        self.assertIn("attackSeconds / (0.6 * log(100.0))", engine)
        self.assertIn("decaySeconds / log(100.0)", engine)
        self.assertIn("releaseSeconds / log(1000.0)", engine)

    def test_parameter_slider_has_real_native_44_point_bounds(self):
        view = (ROOT / "SensorSynthFM/InstrumentControlsView.swift").read_text()
        self.assertIn("InstrumentParameterSlider(value:", view)
        self.assertIn("func makeUIView(context: Context) -> UISlider", view)
        self.assertIn(".frame(height: 44)", view)
        self.assertNotIn("scaleEffect", view)
        self.assertIn("return bounds.contains(point)", view)
        self.assertIn("UIAccessibility.convertToScreenCoordinates(bounds, in: self)", view)

    def test_representable_explicitly_sizes_the_native_control(self):
        view = (ROOT / "SensorSynthFM/InstrumentControlsView.swift").read_text()
        bridge = view[view.index("private struct InstrumentParameterSlider"):]
        self.assertIn("func sizeThatFits(_ proposal: ProposedViewSize", bridge)
        self.assertIn("height: 44", bridge[bridge.index("func sizeThatFits("):bridge.index("func makeCoordinator")])

    def test_instrument_parent_does_not_override_child_identifiers(self):
        view = (ROOT / "SensorSynthFM/SensorFMTestView.swift").read_text()
        instrument = view[view.index("private var instrumentSurface"):view.index("private var performanceSurface")]
        self.assertNotIn('.accessibilityIdentifier("instrument.page")', instrument)
        for identifier in ("instrument.page.title", "instrument.audition.toggle", "instrument.hidden.held.count"):
            self.assertIn(f'.accessibilityIdentifier("{identifier}")', instrument)


if __name__ == "__main__":
    unittest.main()
