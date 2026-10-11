# SSFM participant candidate — Linux source readiness, 2026-10-11

This is a **candidate**, not a frozen or physically qualified build. The test surface is the three existing pages: Performance, Instrument and Matrix. No runtime AI, new preset system, persistence, sequencer, capture, modulation lanes, undo or sound graphic was added. Existing session-only room SAVE behavior is unchanged and does not write to disk.

## One baked starting patch

Launch and RESET START use `SensorModulationMatrix.testStartingPatch()`. Historical `defaultMatrix()` and catalog nonfinite fallbacks remain unchanged.

| Base | Value |
|---|---|
| Carrier frequency (Matrix test tone) | 440 Hz |
| Modulator ratio | 2.0:1 |
| Modulation index | 1.0 |
| Amplitude | 0.10 |
| Attack | 0.020 s |
| Decay | 0.150 s |
| Sustain | 0.70 |
| Release | 0.350 s |
| Filter cutoff | 18000 Hz |
| Filter resonance | 0.0 |
| Filter mode/state | Low pass, bypassed |

| Route | Normalized amount | Numeric excursion |
|---|---|---|
| accelMagnitude → modulationIndex | +0.10 | index 1..2 |
| micAmplitude → amplitude | +0.08 | amplitude .10..18 |
| gyroY → modulatorRatio | +0.5 / 19.9 = 0.02512562814070352 | ratio 1.5..2.5 |

All other 87 cells are zero. Smoothing stays .08/.12/.06. Pitch on Performance and Instrument stays touch-owned. Live sensor values can vary the output; identical bases/routes do not promise identical sensor readings. Conservative means bounded excursion, **not verified comfortable loudness**.

## Reset behavior

RESET START is adjacent to RELEASE ALL on the existing shared 44pt-minimum off-hand rail, ID `performance.reset.start`, in both handedness arrangements and Instrument. It panics all voices through the existing release-all path (including Matrix audition and pending release tails), clears Hold, sets quantized pitch and octave zero, shows audition, restores all bases/routes and LP bypass, and preserves current page and control-hand preference. Reset does not save anything.

After reset, automatic scene-base application is suspended, including a listen already in progress. Only an explicit subsequent LISTEN or REGEN re-enables it. The existing room candidate/preview/session save is retained; it is not the applied starting patch. No scene lifecycle redesign or new persistence.

## Known accessibility deviation — no fourth repair

Historical on-device evidence reports **44pt native slider bounds/hit area but a 34pt iPadOS accessibility frame**, despite three physical repair cycles. This remains a known deviation. It is not equivalent to full VoiceOver qualification.

The native slider hit override, representable sizing and existing accessibility-frame override are preserved. Under `-ui-testing` only, its accessibility value appends runtime `bounds.width`/`bounds.height` and actual `point(inside:with:)` results at upper/lower one-point insets. The suffix is computed on every accessibility read after layout, never a cached 44pt number or invented rectangle. Ordinary accessibility values stay unchanged.

The failing XCUITest now checks measured native height and width >=44, actual upper/lower hit results, `isHittable`, and parameter edit behavior, rather than claiming `XCUIElement.frame.height` measures the native hit region. The original native bounds unit test remains, and a new test changes runtime bounds to verify evidence is not cached. No parent-ID masking, scaling, AX threshold reduction or fourth repair attempt.

## Verification boundary

Linux source contracts: 62 tests, OK; baseline 57. These check source wiring, exact constants and preservation, **not Swift compilation or DSP/physical behavior**. Native tests authored in the existing test files cover starting bases and every route, low/mid/high excursions, bridge reset, panic and stale tail cleanup, derived hit evidence, both rail hands, relaunch/default copy, and audition/Hold/pitch/filter reset. Native execution is pending.

Protected project file, icons and dependency lock match both starting tip `6b8982331a1da6eb647d4b5a930cfa8ebd5f184f` and accepted baseline `a28a0203475500ce2029fc6195b2733d10bb63f9`; original PCM test matches starting tip byte-for-byte. No dependency changes.

Next gate: exact-candidate Xcode compilation, native behavior/PCM/XCUITest execution, then owner physical loudness, multitouch, rail reachability, reset-during-listen and accessibility review. Record control hand in session setup. Only the owner physical pass can authorize freezing.

## Complete participant string audit

Only literal text/status presentation changed; IDs, typography and geometry remain except the requested reset button. The Diagnostics sheet internal engineering copy and unused mock PerformanceView remain untouched. Repeated literals count as one change below; legend changes include both visual and accessibility labels; AT LIMIT occurs twice in Matrix.

### `SensorSynthFM/InstrumentControlsView.swift`

| Before | After |
|---|---|
| `Touch pitch stays authoritative. Carrier base drives the legacy Matrix audition note only.` | `Your finger sets note pitch. Carrier frequency sets the Matrix test tone.` |
| `One envelope per note. Release time is captured on note-off; editing a tail never retriggers it.` | `Each note has its own fade in and fade out. Release changes apply to the next note you let go.` |
| `Cutoff is logarithmic (center in BP). Resonance: LP/HP 0…+6 dB; BP bandwidth 2400…300 cents. Bypass leaves routes editable but inaudible.` | `Lower the low-pass cutoff for a darker sound. Resonance emphasizes the cutoff. Bypass turns the filter off, not its settings.` |
| `BASE \(target.formatted(bridge.baseValue(for: target))) · LIVE \(target.formatted(bridge.outputValue(for: target)))\(bridge.outputIsClamped(target) ? " · CLAMPED" : "")` | `BASE \(target.formatted(bridge.baseValue(for: target))) · LIVE \(target.formatted(bridge.outputValue(for: target)))\(bridge.outputIsClamped(target) ? " · AT LIMIT" : "")` |

### `SensorSynthFM/SensorFMTestView.swift`

| Before | After |
|---|---|
| `GEN 0 · RATIO UNCHANGED` | `VERSION 0 · RATIO UNCHANGED` |
| `SCENE FINGERPRINT + MATRIX` | `ROOM SOUND + MATRIX` |
| `SCENE FINGERPRINT` | `ROOM SOUND` |
| `SCENE PREVIEW` | `ROOM PREVIEW` |
| `SCENE BASE` | `ROOM PATCH` |
| `SCENE DESCRIPTORS` | `ROOM DETAILS` |
| `FREEZE HOLDS SCENE DESCRIPTORS; RAW SENSOR ROUTING REMAINS LIVE.` | `FREEZE HOLDS ROOM SOUND; MOTION AND MIC ROUTES STAY LIVE.` |
| `GEN \(generation) · \(changed ? "RATIO CHANGED" : "RATIO UNCHANGED")` | `VERSION \(generation) · \(changed ? "RATIO CHANGED" : "RATIO UNCHANGED")` |
| `ACTIVE HALOS · RELEASED ENVELOPES · HELD EDGE MARKERS` | `ACTIVE HALOS · FADING NOTES · HELD EDGE MARKERS` |
| `RELEASED envelope voice \(indicator.voiceID + 1)` | `FADING note voice \(indicator.voiceID + 1)` |
| `SENSOR TIMBRE UNDERLAY: \(Int((bridge.performanceTimbreAmount * 100).rounded()))%` | `SENSOR SOUND CHANGE: \(Int((bridge.performanceTimbreAmount * 100).rounded()))%` |
| `TOUCH B\(beganTouchCount) M\(movedTouchCount) R\(releasedTouchCount) · LAST \(lastTouchEvent) · PITCH \(first)→\(last) · PITCH CHANGED \(changed ? "YES" : "NO")` | `TOUCHES DOWN \(beganTouchCount) · SLIDES \(movedTouchCount) · LIFTED \(releasedTouchCount) · LAST \(lastTouchEvent) · PITCH \(first)→\(last) · PITCH CHANGED \(changed ? "YES" : "NO")` |
| `Selected but neutral. Adjust amount to activate this route` | `Selected but neutral. Turn the amount up to hear this route` |
| `ADJUST TO ACTIVATE` | `TURN AMOUNT UP` |
| `CLAMPED` | `AT LIMIT` |
| `DIAG` | `DETAILS` |
| `Diagnostics` | `Details` |
| `NO SEED / uppercase hexadecimal seedHash (status expression)` | `NOT CAPTURED / READY` |

### Added strings (not replacements)

- `RESET START`, control ID `performance.reset.start`.
- Internal recovery reason `reset to start`; not musician-facing copy.
- Test-only accessibility suffix ` | HIT_BOUNDS width=\(bounds.width) height=\(bounds.height) upper=\(upper) lower=\(lower)` under `-ui-testing`. Ordinary participant accessibility values unchanged.
