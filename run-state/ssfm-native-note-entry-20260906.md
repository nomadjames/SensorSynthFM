Objective: implement the bounded native SensorSynthFM Performance note-entry slice from 7bf401c6d1546ca23b91f5fd18f1962c9560070a.

Constraints: isolated worktree only; preserve accepted matrix repair; no Xcode or device claims; no loop/latch/overflow system.

TDD RED
- Command: `python3 -m pytest -q tests/test_native_note_entry_contract.py`
- Expected failure: new native model/surface files and required UI identifiers are absent.
- Actual result: `6 errors`, first error `FileNotFoundError: .../SensorSynthFM/NoteEntryModel.swift`.

Implementation
- Added deterministic seven-degree pitch/touch state with eight-lane quantization, named 15% hysteresis, freehand octave mapping, stable touch/voice identity, bounded octave offsets, cancellation/release-all recovery, and passive timbre-only sensor state.
- Added native UIKit multiple-touch bridge with background/window-loss recovery.
- Refactored FMEngine to a pre-connected ten-node voice bank while preserving noteOn()/noteOff().
- Made Performance the default surface with structural handedness rail, explicit matrix round-trip, accessibility identifiers, and UI-test runtime suppression preserved.
- Kept matrix mode's complete routing behavior; Performance ignores sensor carrier routing and applies only global timbral parameters.

Linux GREEN
- Command: `python3 -m pytest -q`
- Result: `20 passed in 0.19s`.
- `git diff --check`: passed.
- Focused secret/danger scan: passed.
- `swiftc`: unavailable; `xcodebuild`: unavailable on Linux.

Next action: run the pending Xcode unit/UI tests and physical iPad checks on the Mac/Nomadpad. Do not claim those checks from Linux.
