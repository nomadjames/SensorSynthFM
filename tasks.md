# SensorSynth FM — Task List

Update this file at the start and end of every work session.
Always pick ONE task to work on. Do not try to do multiple things at once.

---

## Current Sprint: Foundation

### Next Up
- [x] Session 1: Add AudioKit as a Swift Package dependency to the Xcode project — DONE
- [x] Session 1: Create AudioEngine.swift — native AVAudioEngine sine wave — DONE
- [x] Session 1: Create SineTestView.swift — play/stop + frequency/volume sliders — DONE
- [x] Session 1: Build and run on simulator — sound confirmed working — DONE
- [x] Session 1: Commit and push to GitHub — DONE

### After Sound Works
- [x] Session 2: Replace sine wave with AudioKit FMOscillator — DONE (FMEngine.swift)
- [x] Session 2: Add sliders for carrier frequency, modulator frequency, modulation index, amplitude — DONE (FMTestView.swift)
- [ ] Session 2: Confirm real-time FM timbral changes with sliders — needs build/run on Mac

### Sensor Foundation
- [x] Session 3 (prepped Mar 31 2026): SensorFMBridge.swift created — routes accel magnitude → modulationIndex, mic amplitude → amplitude, gyroY → modulatorRatio. IIR smoothing per mapping, all audio-thread safe.
- [x] Session 3 (prepped Mar 31 2026): SensorFMTestView.swift created — live sensor bars, mapped-value readouts, per-mapping enable toggles, raw sensor panel, FM sliders and play/stop. Landscape dark theme.
- [ ] Session 3: git pull on Mac, add both files to Xcode target, build and run — confirm sensor values appear and tapping the table changes timbre.

- [ ] Session 4: Add Vision framework optical flow from front camera
- [ ] Session 4: Display motion magnitude on screen
- [ ] Session 4: Route camera motion to a second FM parameter

- [ ] Session 5: Add microphone amplitude follower via AudioKit input tap
- [ ] Session 5: Route mic amplitude to a third FM parameter
- [ ] Session 5: Test all three passive sources simultaneously

---

## Backlog (Later Phases)

### FM Engine
- [ ] Expand to full 4-operator architecture (A1, A2, B1, B2)
- [ ] Implement all 8 algorithms with visual routing diagram
- [ ] Per-operator envelopes (ADSR)
- [ ] Post-FM multimode filter (LP/HP/BP)
- [ ] 8-voice polyphony

### MPE
- [ ] Design voice allocation system for MPE from the start
- [ ] Per-touch pitch bend (Y-axis)
- [ ] Per-touch pressure
- [ ] Per-touch slide (X-axis movement)

### Sensor Modulation
- [ ] Sensor modulation assignment matrix (connect any source to any destination)
- [ ] Smoothing and scaling controls per mapping
- [ ] Sensor capture: record a segment of sensor data
- [ ] Sensor loop: loop captured segment as repeatable modulation

### Sequencer
- [ ] 16-step sequencer, 4 tracks
- [ ] Per-step parameter locks
- [ ] Controlled randomization

### UI / UX
- [ ] Connect mockup screens to real audio engine
- [ ] Preset save/load system
- [ ] Design guidelines refinement based on real usage
- [ ] Accessibility review

### Ship
- [ ] App Store metadata and screenshots
- [ ] TestFlight beta
- [ ] App Store submission

---

## Completed
- [x] Created Xcode project (Antigravity, Feb 2026)
- [x] Created SwiftUI mockup screens: Performance, FM Engine, Sensor Modulation
- [x] Set up landscape preview orientation
- [x] Created project documentation (.md files)
- [x] Set up .gitignore
- [x] GitHub repo created and pushed: github.com/nomadjames/SensorSynthFM
- [x] README.md written for GitHub
- [x] SensorManager.swift written (Antigravity), reviewed and patched (FFT memory leak fix, mic permission added)
- [x] AudioKit added as Swift Package dependency
- [x] Medium article outline and first draft created
- [x] Workflow plan document created (tool allocation across Claude, Antigravity, Max/MSP, Gemini)

---

## Session Notes
(Write one sentence here at the end of each session about what to do next)

Feb 2026 Session 1: Mockups complete. Next: add AudioKit and get first sound out of the app.
Feb 2026 Session 2: GitHub connected, SensorManager written by Antigravity and patched, AudioKit added. Next: write AudioEngine.swift, then build a sine wave test view.
Feb 2026 Session 3: AudioEngine.swift written using native AVAudioEngine (not AudioKit — had linking issues). Sine wave test working on simulator. Next: replace sine wave with FM oscillator (Session 2 tasks in sprint).
Feb 19 2026 Session 4: Upgraded to macOS Tahoe + Xcode 26.3. Set up Claude Agent in Xcode (signed in). Confirmed Gemini 3.1 Pro access via Antigravity and AI Studio. Created workflow.md (tool allocation plan). Updated CLAUDE.md with multi-tool context. Next: Session 2 FM oscillator tasks, routed through Xcode Claude Agent.
Mar 27 2026 Session 5: Created FMEngine.swift (AudioKit FMOscillator replacing AVAudioEngine sine wave) and FMTestView.swift (landscape split-panel UI with sliders for carrier freq, mod ratio, mod index, amplitude). Updated SensorSynthFMApp entry point to FMTestView. Next: git pull on Mac, build, confirm FM sound and real-time slider control, then mark final Session 2 task complete.
Mar 31 2026 Session 6 (Vera — remote prep): Created SensorFMBridge.swift (sensor-to-FM routing with IIR smoothing, per-mapping toggles, audio-thread safe) and SensorFMTestView.swift (split-panel: sensor readouts + FM controls). Ready for build test on Mac. Next: git pull, add both files to Xcode target, swap SensorFMTestView into SensorSynthFMApp.swift, build and run, tap table and confirm timbre change.
Sep 20 2026 Session 8 (Boddicker + James, physical iPad review): Hold sustain, same-pitch deduplication, fluid retargeting, occupied-pitch merge, selective removal, and Hold-off active-touch ownership passed on the Nomadpad. James found the active halo too small except during motion, the note/Hz label on the playing-arm side, and the release indicator too brief. Follow-up tuning increases the halo to 52 points, moves the label to the opposite side of the playing arm, and lengthens the matched audio/visual release envelope to 350 ms. Next: pull the follow-up commit, rebuild on the Nomadpad, and recheck those three feedback details before Freehand and sustained-play review.
