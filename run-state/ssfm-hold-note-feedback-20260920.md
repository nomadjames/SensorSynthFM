# SSFM Hold + note-feedback build run state

## Objective

Create a local human-review candidate from `d297975` that adds the accepted visible Hold/Chord Latch behavior and the bounded post-practice note interaction feedback without altering the qualified baseline checkout.

## Workspace and boundary

- Worktree: `/home/james/.hermes/profiles/boddicker/worktrees/ssfm-hold-note-feedback-20260920`
- Branch: `work/ssfm-hold-note-feedback-20260920`
- Baseline: `d297975b289ead42f02732417947d4b3065e3bb7`
- No push, merge, publication, participant outreach, or canonical-checkout edits.
- No loop/sequence capture, Record/Overwrite, cameras, patch generation, dependency additions, or broad matrix redesign.

## TDD evidence

Initial implementation RED:
- `tests/test_hold_note_feedback_contract.py` was added before production edits by the bounded implementation worker.
- Its first focused run failed because the new Hold and note-feedback source contracts were absent.

Repair RED after independent review:
- Command: `python3 -m unittest -v tests.test_hold_note_feedback_contract`
- Result: four focused failures covering simultaneous held-voice reuse, duplicate pitch ownership, held marker/remapping, and accessibility guidance.

Current deterministic GREEN:
- Command: `python3 -B -m unittest discover -s tests -p 'test*.py' -v`
- Result: `Ran 42 tests in 0.013s`, `OK`.
- Command: `git diff --check`
- Result: passed with no output.

Unavailable on Linux:
- `swiftc`: unavailable.
- `xcodebuild`: unavailable.
- No claim is made for compilation, simulator behavior, physical multitouch, audio output, orientation, VoiceOver, or iPad stability.

## Implemented behavior

- Pitch surface is high-at-top and low-at-bottom in Quantized and Freehand modes.
- Active contact state now tracks X and Y for finger-following indicators.
- Note feedback supplies note name and Hz; Freehand also supplies signed approximate cents.
- Active, released-envelope, and held states use distinct shape/text cues.
- Released indicators decay with the programmed 180 ms audio release window and expire individually.
- iPad orientations are restricted to landscape left/right in both build configurations.
- Visible Hold control is on the mirrored off-hand rail.
- Hold transfers released pitches to one unattended held owner per pitch.
- Touching an unattended held pitch reuses and retriggers its voice only when that voice is not already controlled by another touch.
- Simultaneous duplicate-pitch touches receive independent active voices; duplicate releases cannot replace or orphan the existing held owner.
- Dragging a held owner retargets it; occupied destinations merge to one held owner and release the displaced active voice on touch-up.
- Held ownership follows a stable held-note identifier rather than a pitch key, so dragging through an occupied held pitch cannot steal or relocate the destination owner.
- Turning Hold off releases unattended held voices but preserves voices still owned by active touches.
- Mode and octave changes remap active and held voices at stable marker positions; collided held owners are deterministically displaced and released.
- Continuous sensor parameter updates preserve the programmed 180 ms amplitude release ramp instead of forcing releasing voices immediately to zero.
- Hold-modifier selective removal uses nearest marker Y with bounded tolerance; releasing the modifier after removal does not toggle Hold off.
- Held markers expose an accessibility action for selective removal; the native surface has a label and hint.
- Release All clears active touches, held ownership, indicators, modifier state, and engine voices.

## Changed files

- `SensorSynthFM.xcodeproj/project.pbxproj`
- `SensorSynthFM/FMEngine.swift`
- `SensorSynthFM/NoteEntryModel.swift`
- `SensorSynthFM/PerformanceNoteSurface.swift`
- `SensorSynthFM/SensorFMTestView.swift`
- `SensorSynthFMTests/SensorSynthFMTests.swift`
- `SensorSynthFMUITests/SensorSynthFMUITests.swift`
- `tests/test_hold_note_feedback_contract.py`

## Review state

The first independent read-only review found seven issues, including four high-severity ownership/mapping defects. The second review found three remaining paths: stale ownership after an occupied merge, stale ownership after remapping, and sensor updates truncating the release ramp. All findings were repaired with new failing contracts before production changes. The final narrow review found no actionable high- or medium-severity defects and marked the diff ready for Mac/Xcode human review.

## Physical iPad review, 2026-09-20

James verified that Hold sustains a released note, same-pitch retrigger does not duplicate it, retargeting is fluid, occupied-pitch merge keeps the destination note, selective removal stops only the selected note, and disabling Hold preserves an actively touched voice until finger release.

Quantized feedback exposed three tuning defects: the 38-point active halo was too easy to lose beneath the finger, the note/Hz label was placed on the playing-arm side, and the 180 ms release indicator disappeared too quickly. The follow-up candidate uses a 52-point halo, reverses the handedness-aware label side, and matches the audio and visual release lifetime at 350 ms. These three corrections require one focused Nomadpad retest.

The first retest confirmed the label side and longer release lifetime. A centered 52-point halo remained hidden beneath a stationary fingertip, and the released ring turned white instead of preserving the active orange briefly. The second follow-up uses an 88-point outer reticle and keeps the dashed released ring orange throughout its 350 ms fade.

## Remaining human gate

Before accepting or merging, run the Xcode unit/UI suites and the focused Nomadpad review:
1. ordinary touch, move, and release;
2. single-note and multi-note Hold;
3. retrigger, retarget, duplicate pitch, and occupied-pitch merge;
4. selective held-note removal without disabling Hold;
5. Hold-off while a finger remains active;
6. Quantized and Freehand labels, cents, lanes, and high-at-top mapping;
7. left/right rail mirroring, landscape orientation, VoiceOver actions, and Release All;
8. sustained play sufficient to expose lockup or stuck-note behavior.
