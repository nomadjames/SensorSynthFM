# Private SSFM Instrument foundation handoff

**Status: Linux source candidate finished; NOT compiled, rendered, installed, or uploaded.**

## Exact source and boundaries

- Worktree: `/home/james/.hermes/profiles/boddicker/worktrees/ssfm-instrument-foundation-20261006`
- Branch: `work/ssfm-instrument-foundation-20261006`
- Accepted base: `a28a0203475500ce2029fc6195b2733d10bb63f9`
- Candidate identity: local branch HEAD plus `run-state/instrument-source-manifest.json`. Parent must use the exact reviewed commit, not the original July main.
- Parent plan: `/home/james/.hermes/profiles/boddicker/run-state/ssfm-instrument-foundation-20261006-plan.md`
- Private portable Git bundle is prepared alongside the candidate after its local commit; read its exact ref/hash from `run-state/instrument-bundle-verification.log`. Do not publish this handoff, bundle or review evidence.
- Worker performed no Mac/SSH work, installs, signing/auth/provisioning changes, external pushes, TestFlight uploads, tester contact or board transitions. Mac safeguard remains closed pending the explicit approval requested by the parent. Original `~/SensorSynthFM-Hold-Review` and its dirty Xcode project must remain untouched.

## What is wired

`SensorSynthFMApp → ContentView → SensorFMTestView → InstrumentControlsView → SensorFMBridge → FMEngine` is the real app path. The obsolete `FMEngineView` is not used for this increment.

- Reach Instrument on the existing off-hand rail; return to Performance or Matrix there. Matrix also has Instrument and immediate Release All navigation controls. Left/right placement follows accepted hand preference.
- Instrument exposes the four accepted FM bases plus amplitude ADSR, filter cutoff/resonance, LP/HP/BP and bypass. Controls use the shared catalog, explicit units, base/live readouts and 44-point targets. Audition can be hidden; the accepted native UIKit note surface, pitch mapping, Hold ownership, feedback and rail are reused.
- Performance↔Instrument and audition hiding cancel disappearing contacts without creating new Hold owners or discarding existing ones. UIKit cancellation does not latch a fresh Hold note. Root scene-phase recovery releases all even when audition is hidden. Matrix transitions retain the accepted release-all policy.
- The fixed ten-voice graph is built in init: `FMOscillator → AmplitudeEnvelope → LowPass → HighPass → BandPass → voice mixer → native PeakLimiter → output mixer`. Inactive filter units are bypassed; no note/sensor operation reconnects it. Bypass defaults true. The envelope is never bypassed.
- A note-on resets/opens only that native voice envelope. Pitch remaps and sensor frames never reset/open/close gates. Note-off snapshots release, freezes the releasing voice's ADSR and oscillator amplitude, and schedules generation-checked cleanup after release + 30 ms. Release All cancels/invalidates active and pending owners immediately, stops oscillators and resets native envelope/filter/limiter histories.
- Matrix has nine real sources and ten supported continuous targets. Original IDs 0…3 and all source IDs are unchanged; ADSR/filter IDs append 4…9. Expanded rows scroll with the same selected editor and neutral/removal semantics. No fake LFO/envelope source cells.
- The bridge applies one coherent frame to the engine, retaining touch-owned pitch in Performance/Instrument. Scene generation still changes only its accepted four bases; new settings and routes survive it.

## Catalog / native safety choices

| Target | Bounds | Default |
|---|---|---|
| Carrier | 20…2000 Hz | 440 Hz |
| Mod ratio | 0.1…20 | Matrix 4.25 |
| Mod index | 0…10 | Matrix 0 |
| Amplitude | 0…1 | Matrix 0.1 |
| Attack / decay | 5…5000 ms | 5 / 100 ms |
| Sustain | 0…100% | 100% |
| Release | 20…5000 ms | 350 ms |
| Filter cutoff / BP center | 20…18000 Hz, log-normalized | 18000 Hz |
| Filter resonance | 0…100% | 0% |

LP/HP map resonance to 0…+6 dB, **not** native +40 dB. BP maps it to 2400…300 cents bandwidth (higher resonance = narrower band). Native limiter: 1 ms attack, 30 ms decay, unity pre-gain; fixed post-limiter volume 0.8. These are conservative control choices, **not measured headroom proof**. Default attack, changed native release curve and fixed output gain need owner listening against the accepted build; bypass preserves the oscillator timbre path, not a claim of bit-identical audio or volume.

Non-finite catalog inputs fall back to declared defaults; invalid routes become zero; invalid gyro is neutral. Native boundaries clamp all global parameters, reject non-finite notes/pitch and bound touch pitch to 20…20000 Hz. Package lock/project/signing settings and all default/dark/tinted icon bytes are unchanged.

## Linux evidence and native tests

Run from the exact worktree:

```sh
PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s tests -v
python -m py_compile tests/*.py
git diff --check
```

The new source-contract file is `tests/test_instrument_foundation_contract.py`. It checks catalog IDs, fixed native graph, production page/bridge/engine wiring, release snapshots/tokens, contact-only recovery, background panic, icon/lock parity and presence of real native PCM/UI test gates. The old release-string contract was replaced with stronger native-release preservation assertions; the old bridge didSet-string assertions now check the coherent frame and unchanged pitch policy. No dead ramp code was retained merely to satisfy a string check. RED log precedes implementation; final GREEN and scope/parity evidence are in candidate `run-state/`.

Written but **not executed here**:
- `SensorSynthFMTests/InstrumentFoundationTests.swift`: 12 native behavior/integration tests, including real engine parameter application, per-voice native state/identity, release snapshot, stale cleanup, panic/stop, finite inputs, ownership, scene/base and route isolation.
- `SensorSynthFMTests/InstrumentAudioRenderTests.swift`: 3 Debug native offline tests pulling **the exact production engine graph**. They check audible attack/decay/sustain/release, LP/HP/BP/bypass PCM changes, finite samples, initial/switching transients, ten coherent unison voices, output peak ≤0.95, and panic silence. They retain actual PCM WAV and metric attachments in xcresult when run. A failing bound is a blocker, not permission to weaken the assertion without measured diagnosis.
- `SensorSynthFMUITests/InstrumentFoundationUITests.swift`: 4 reachable-page UI tests for all ten sliders, modes/bypass, audition visibility, retained Hold, handedness, immediate Release All, last Matrix row/source route activation/removal, and unchanged Matrix release policy. Screenshot attachments are retained. Existing accepted Swift/UI tests remain.

No Swift executable or parser is installed on this Linux host. Python checks are SOURCE checks, not Swift type checking, DSP/render success, UI screenshots, physical multitouch/capacity or private distribution proof.

## Approved-Mac verification sequence (parent-owned; commands below NOT run)

1. Obtain explicit Mac-impact approval. Inspect tools, device OS, available SDK/simulators, scheme/test discovery and signing state. Back up/hash the existing dirty project edit if the parent needs to inspect that clone; never replace it. Prefer a **new independent private clone of the full bundle**, so the original Mac clone need not be touched at all. Verify bundle SHA, exact branch HEAD and clean candidate status.
2. Suggested new source path: `~/SensorSynthFM-Instrument-Foundation-Review`. Evidence/DerivedData path: `~/SSFM-Instrument-Foundation-Evidence/<exact-reviewed-commit>/`. These are proposed paths, not existing Mac artifacts.
3. Run `xcodebuild -version`, `xcodebuild -list -json -project SensorSynthFM.xcodeproj`, and `xcodebuild -showdestinations -project SensorSynthFM.xcodeproj -scheme <verified-scheme>` **after** approval. Choose an actual iPad simulator UDID/runtime compatible with the source's iOS 26.2 target. Do not guess the scheme/UDID or silently change deployment/signing metadata.
4. From the independent candidate, using actual discovered `$SCHEME`, `$SIM_ID`, and an absolute `$EVIDENCE`, these are proposed verification commands:

```sh
xcodebuild -project SensorSynthFM.xcodeproj -scheme "$SCHEME" \
  -configuration Debug -destination "platform=iOS Simulator,id=$SIM_ID" \
  -derivedDataPath "$EVIDENCE/DerivedData" \
  -resultBundlePath "$EVIDENCE/NativeTests.xcresult" \
  -parallel-testing-enabled NO -only-testing:SensorSynthFMTests \
  test CODE_SIGNING_ALLOWED=NO

xcodebuild -project SensorSynthFM.xcodeproj -scheme "$SCHEME" \
  -configuration Debug -destination "platform=iOS Simulator,id=$SIM_ID" \
  -derivedDataPath "$EVIDENCE/DerivedData" \
  -resultBundlePath "$EVIDENCE/UITests.xcresult" \
  -parallel-testing-enabled NO -only-testing:SensorSynthFMUITests \
  test CODE_SIGNING_ALLOWED=NO

xcodebuild -project SensorSynthFM.xcodeproj -scheme "$SCHEME" \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$EVIDENCE/DeviceCompileDerivedData" \
  build CODE_SIGNING_ALLOWED=NO
```

5. Record exact commands, exit codes, source commit, test enumeration/counts, xcresult paths and **first real compile/runtime error** if any. Diagnose rather than treating Linux green as permission to install. Check explicit AudioKitEX import against the existing transitive pinned product; no dependency upgrade was made. Do not install/update packages or toolchains to conceal a blocker.
6. Export/view xcresult metric, WAV and screenshot attachments in Xcode. Inspect layout at both landscape directions/hand preferences and audition shown/hidden; scroll to all ten targets. Listen to attack/sustain/release and mode/bypass switching at low monitoring volume. Inspect release cutoff/cleanup and any click/zipper artifact. Rendering must be finite, audible where expected and below the bound including attacks and mode-switch transients. This bounded sweep does not certify all parameter combinations or real-time capacity.
7. Only after these gates pass, use existing user-owned signing in the independent project for a physical build/install. No `-allowProvisioningUpdates`, certificate/key creation or account mutation without separate explicit authorization. If SSH signing/keychain interaction fails, stop and use the user-owned Xcode GUI—do not retry around the safeguard. Verify exact installed commit/build and launch, then owner-test five/ten contacts, Hold selective removal, dragging/remaps, long release with sensor changes, hidden-audition background recovery and panic/stop. Simulator single-touch tests are not physical multitouch proof.

## Private archive / TestFlight gate (not executed)

- James reports Developer membership; no Team ID, App Store Connect role/auth, existing app record or tester group was verified by this worker. The source bundle identifier is `com.sensorsynthFM.SensorSynthFM`; its association with an App Store Connect record must be verified, not inferred.
- Discover the actual distribution team, existing signing/profiles and upload entitlement. Use user-owned UI/vault for credentials, never chat or scripts containing secrets. Read existing uploaded build numbers and choose a monotonically higher value in the isolated candidate only; no guessed number/team/app IDs.
- After source, render, UI and physical-listening gates, archive via the verified scheme/user signing to `$EVIDENCE/SensorSynthFM.xcarchive`. Use Xcode Organizer's validated **App Store Connect / private TestFlight** distribution with a verified record; export, if actually needed, to `$EVIDENCE/export/` using real validated export settings. No fabricated export plist or claimed upload command.
- Read back the exact archive/upload build version, processing status, compliance state and private availability in App Store Connect. An upload's return status alone is not distribution proof. TestFlight builds have a 90-day life; membership does not remove that limit.
- No App Store public release, external testers/invites/public links, beta-review submission or participant contact from this authority. Even internal tester assignment should be an explicit owner-selected private group, not provider defaults.

## Explicit remaining gates / non-goals

Swift compilation and tests, native PCM/headroom/listening, screenshot review, device signing/install/capacity and TestFlight are all still unverified. Instant native filter bypass/mode changes and 60 Hz parameter setters may need click/zipper correction if actual audio reveals it; the graph is intentionally fixed and no custom render callback was added. Output limiter performance is not presumed safe from its presence alone.

Second routable sound envelope, LFOs, delay/reverb, preset/recovery system, ribbons/macros, Capture/sequencer and AV displays are not implemented or mocked. This first increment does not close full October4 MVP cards or certify device readiness. Parent owns source review, private transfer/deployment and all board transitions.
