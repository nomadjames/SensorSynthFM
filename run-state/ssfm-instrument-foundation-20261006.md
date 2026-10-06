# SSFM instrument foundation candidate

## Authority / target
Only this worktree, branch `work/ssfm-instrument-foundation-20261006`, base `a28a0203475500ce2029fc6195b2733d10bb63f9`. Parent plan: `/home/james/.hermes/profiles/boddicker/run-state/ssfm-instrument-foundation-20261006-plan.md`.
No Mac/SSH, installs, provisioning, uploads, external pushes, public outreach, or board completion. Accepted icons untouched. This is first increment, not full October4 MVP.

## Phases
- 2026-10-06 17:28–17:30 EDT: inspected production engine, bridge, matrix, note model/native UIKit surface, reachable view, project groups and existing tests. Baseline `python -m unittest discover -s tests -v`: 43 PASS. No `swift` executable.
- 2026-10-06 17:30 EDT: implementation phase started. Native APIs inspected at pinned revisions. `Gated` resides in AudioKitEX `Node+Triggerable.swift`, not a Protocols/Gated path; openGate calls au.trigger, closeGate calls au.detrigger. LP/HP bypass via Node start/stop; BP resonance is bandwidth, not dB.

## Decisions / upcoming checks
ADSR and filters per voice; immutable topology. Generation-checked release cleanup plus snapshotted native release duration; no control-frame gate resets. Catalog appended target IDs. Coherent sink update. Hideable accepted audition surface and explicit touch-only cancellation for Instrument transitions, held ownership retained; accepted Matrix transitions still release all.

## Finished Linux implementation / evidence

- 2026-10-06 17:31 EDT: focused SOURCE RED before implementation: 8 tests, 5 failures + 2 missing-file errors, 1 preservation pass. Condensed real output: `run-state/instrument-red-summary.log`.
- 2026-10-06 17:36 EDT: initial production engine/page/catalog/bridge wiring in place. Remaining interim source failures were old release-ramp/didSet string contracts and missing native tests, not native runtime results.
- 2026-10-06 17:40 EDT: 51/51 initial source checks green. Native behavior/UI tests written. Installed Gated source located and verified at exact locked AudioKitEX revision `23e8e3bffd9fbc1dffa72f1d47c7f714dd777288` (`Node+Triggerable.swift`, SHA256 `199e0bf182336fd3ceeffa477afca4e8e0038525c31070bd83cae618c1f5b111`). Native envelope DSP, LP/HP/BP, Node bypass/reset, limiter, Mixer and AudioEngine APIs inspected at pinned versions. No dependency changes.
- 2026-10-06 17:44 EDT: 12 Swift behavior/integration tests, 3 exact-production-graph PCM tests with WAV/metric attachments, 4 XCUITests with screenshots written; NONE executed. Native PCM assertions include envelope shape, filter modes/bypass, finite/peak bounds and panic silence.
- 2026-10-06 17:49 EDT: `python -m py_compile tests/*.py`: exit 0. Scoped added-source private-key/token pattern scan: PASS, not a comprehensive security scanner. No Swift toolchain/parser present; none installed.
- 2026-10-06 17:53 EDT: final post-review `PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s tests -v`: **53 PASS**, exit 0, 0.038s (`run-state/instrument-green-final.log`). `git diff --check`: exit 0. Final review removed dead defaults/references and resets reused-note filter histories without touching control-frame gates or graph topology.

### Final changed source files (14)

Production: `SensorSynthFM/{FMEngine,InstrumentControlsView,NoteEntryModel,PerformanceNoteSurface,SensorFMBridge,SensorFMTestView,SensorModulationMatrix}.swift`.
Swift tests: `SensorSynthFMTests/{InstrumentFoundationTests,InstrumentAudioRenderTests,SensorSynthFMTests}.swift`; `SensorSynthFMUITests/InstrumentFoundationUITests.swift`.
Linux tests: `tests/{test_instrument_foundation_contract,test_hold_note_feedback_contract,test_review_repair_contract}.py`.

Source and preserved-asset SHA256s: `run-state/instrument-source-manifest.json`. New files are included by existing Xcode filesystem-synchronized groups; no pbxproj edit. All three icons + Contents.json, project file and Package.resolved equal base bytes. Obsolete view files untouched.

Read-only other-checkout observations at 17:49: accepted Hold checkout remains HEAD `a28a0203475500ce2029fc6195b2733d10bb63f9`, branch `work/ssfm-hold-note-feedback-20260920`, no tracked edits (an existing untracked tests/__pycache__ was observed and LEFT ALONE). Canonical `/home/james/projects/SensorSynthFM` remains July main HEAD `6a7683f7c2899e0bed5475cce652f7ef8886b4d3` and is dirty in multiple source/docs/project files; LEFT ALONE. Worker made no writes outside the candidate, and did not attempt Mac/SSH.

### Review / intentional simplification

- One uniform catalog/output vector instead of duplicated per-parameter output/range switches. Existing IDs and FM mapping preserved.
- Native per-voice DSP only, fixed serial topology, no custom callback or new dependency. Coherent frame eliminates property-observer fanout; discrete filter controls apply separately.
- Release guard covers both oscillator amplitude and all ADSR values. Generation validation protects reused voices even if a canceled work item executes. Native tail state never changes its release duration on sensor frames.
- Real note-on resets native filter histories as well as the envelope, so a reused voice cannot carry a prior note's resonant history into its new attack. Pitch remaps/sensor frames never reset these histories.
- Removed superseded unused 350ms engine constant and old ramp code; default preservation is asserted against the production catalog instead. No dead implementation retained to pass string checks.
- Removed redundant graph mixer/output mixer stored references; AudioKit's output retains the immutable graph. Native reset/stop remains for immediate panic safety.
- Touch-only cancellation is distinct from panic. Canceled contacts cannot latch fresh Hold notes; previously held owners survive Instrument navigation; root background panic works even with no audition UIView. Released feedback snapshots actual release duration and has non-reused IDs.
- No avoidable dependency/routing framework/factory. Do not shrink further: per-voice cleanup tokens, native headroom gate, accessibility and ownership cancellation protect correctness.

## Private handoff / remaining gates

Finished handoff: `run-state/ssfm-instrument-foundation-private-handoff.md`, with exact source, controls/bounds, native and UI test commands, proposed independent Mac clone + external DerivedData/xcresult/archive/export paths, render/screenshot/device gates, signing/ASC metadata discovery and private-only upload/readback boundaries. Portable bundle/commit identity will be recorded by the final local packaging command; no external push.

Linux candidate finished, **not device ready**. Swift compilation, actual PCM/headroom/listening (including possible native bypass/parameter click/zipper behavior), UI screenshot review, physical touch capacity, signing/install and TestFlight are unverified. Mac-impact approval is still blocked; parent owns the next gate and all board transitions. No full October4 MVP/card completion claimed.
