"""Linux SOURCE contracts only; native behavior/render/UI tests require Xcode."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASE = "a28a0203475500ce2029fc6195b2733d10bb63f9"


def source(name):
    return (ROOT / "SensorSynthFM" / name).read_text()


class InstrumentFoundationContractTests(unittest.TestCase):
    def test_catalog_appends_targets_and_handles_nonfinite_log_cutoff(self):
        text = source("SensorModulationMatrix.swift")
        ordered = ["carrierFrequency", "modulatorRatio", "modulationIndex", "amplitude",
                   "ampAttack", "ampDecay", "ampSustain", "ampRelease", "filterCutoff", "filterResonance"]
        cases = text[text.index("enum SensorModulationTarget"):text.index("var id: Int", text.index("enum SensorModulationTarget"))]
        self.assertEqual([line.strip().split()[1] for line in cases.splitlines() if line.strip().startswith("case ")], ordered)
        for token in ("value.isFinite", "log(", "pow(", "var defaultValue", "func formatted"):
            self.assertIn(token, text)

    def test_graph_is_per_voice_native_fixed_and_has_output_safety(self):
        engine = source("FMEngine.swift")
        for token in ("AmplitudeEnvelope(oscillator", "LowPassFilter(envelope", "HighPassFilter(lowPass", "BandPassFilter(highPass", "graphMixer.addInput(voice.bandPass)", "PeakLimiter(graphMixer", "outputMixer.volume = 0.8"):
            self.assertIn(token, engine)
        note_path = engine[engine.index("func noteOn(voiceID:"):engine.index("// MARK: - Parameters")]
        for token in ("addInput", "audioEngine.output", "LowPassFilter(", "AmplitudeEnvelope("):
            self.assertNotIn(token, note_path)

    def test_releasing_voice_snapshots_duration_and_rejects_stale_cleanup(self):
        engine = source("FMEngine.swift")
        off = engine[engine.index("func noteOff(voiceID:"):engine.index("func setFrequency")]
        self.assertIn("voice.envelope.closeGate()", off)
        self.assertIn("voice.releaseSeconds =", off)
        self.assertIn("completeRelease(voiceID: voiceID, generation: generation)", off)
        self.assertIn("voice.generation == generation", engine)
        apply = engine[engine.index("private func applyParameters"):engine.index("private func voice(for")]
        self.assertNotIn("openGate", apply)
        self.assertNotIn("closeGate", apply)
        self.assertIn("voice.releaseWorkItem == nil", apply)

    def test_bridge_applies_one_frame_and_real_engine_implements_it(self):
        bridge = source("SensorFMBridge.swift")
        engine = source("FMEngine.swift")
        self.assertIn("engine.apply(output: output, preserveTouchPitch: performanceMode)", bridge)
        self.assertIn("func apply(output: SensorModulationOutput, preserveTouchPitch: Bool)", engine)
        for name in ("ampAttack", "ampDecay", "ampSustain", "ampRelease", "filterCutoff", "filterResonance"):
            self.assertIn("output.value(for: ." + name + ")", engine)

    def test_instrument_is_reachable_and_uses_existing_note_surface(self):
        view = source("SensorFMTestView.swift")
        instrument = source("InstrumentControlsView.swift")
        for token in ("InstrumentControlsView(bridge: bridge", "enterInstrumentMode()", "instrumentSurface", "instrument.audition.toggle", "cancelSurfaceTouches", "performanceNoteArea", "showInstrument = false"):
            self.assertIn(token, view)
        for token in ("AMPLITUDE ADSR", "PER-NOTE FILTER", "FilterMode.allCases", "bridge.setBaseValue", "target.normalised", "target.denormalised", "minHeight: 44", "instrument.parameter."):
            self.assertIn(token, instrument)
        self.assertIn('releaseAllTouches(reason: "entering matrix")', view)
        self.assertIn('releaseAllTouches(reason: "returning to performance")', view)

    def test_touch_only_cancellation_keeps_holds_but_background_panics(self):
        model = source("NoteEntryModel.swift")
        surface = source("PerformanceNoteSurface.swift")
        self.assertIn("func cancelSurfaceTouches", model)
        self.assertIn('flush(reason: "application backgrounded")', surface)
        self.assertIn("public static func dismantleUIView", surface)
        self.assertIn("cancelSurfaceContacts()", surface)

    def test_icons_and_dependency_lock_match_accepted_baseline(self):
        files = list((ROOT / "SensorSynthFM/Assets.xcassets/AppIcon.appiconset").iterdir())
        files.append(ROOT / "SensorSynthFM.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
        for path in files:
            old = subprocess.check_output(["git", "show", f"{BASE}:{path.relative_to(ROOT)}"], cwd=ROOT)
            self.assertEqual(path.read_bytes(), old, str(path))

    def test_native_behavior_and_ui_tests_are_present_not_claimed_run(self):
        behavior = (ROOT / "SensorSynthFMTests/InstrumentFoundationTests.swift").read_text()
        ui = (ROOT / "SensorSynthFMUITests/InstrumentFoundationUITests.swift").read_text()
        for token in ("releaseSnapshotSurvivesControlFrames", "staleReleaseCannotStopReusedVoice", "allContinuousTargetsReachSinkInOneFrame", "instrumentTransitionCancelsTouchesButPreservesHeldOwner", "nativeGraphKeepsIdentityAcrossControlChanges"):
            self.assertIn(token, behavior)
        for token in ("testInstrumentControlsAndAuditionHoldSurviveNavigation", "testExpandedMatrixRouteCanBeRemoved", "XCTAssert", "adjust(toNormalizedSliderPosition:"):
            self.assertIn(token, ui)

    def test_native_render_gate_pulls_exact_production_pcm_and_retains_evidence(self):
        render = (ROOT / "SensorSynthFMTests/InstrumentAudioRenderTests.swift").read_text()
        for token in ("instrument.verificationAudioEngine", "enableManualRenderingMode(.offline",
                      "engine.renderOffline(", "sample.isFinite", "pcm.peak, 0.95",
                      "Float PCM", "recordingFile?.write(from: buffer)", "XCTAttachment(contentsOfFile:",
                      "testNativeADSRAttackSustainAndSnapshottedReleaseRender",
                      "testNativeFilterModesChangeActualPCMAndBypassRecovers"):
            self.assertIn(token, render)
        self.assertEqual(source("FMEngine.swift").count("audioEngine.output ="), 1)

    def test_hidden_audition_still_has_root_background_panic(self):
        view = source("SensorFMTestView.swift")
        self.assertIn(".onChange(of: scenePhase)", view)
        self.assertIn('releaseAllTouches(reason: "application inactive")', view)
        self.assertIn("endSurfaceTouch(id: id, latchHold: false)", view)
        self.assertIn("milliseconds: indicator.lifetimeMilliseconds", view)


if __name__ == "__main__":
    unittest.main()
