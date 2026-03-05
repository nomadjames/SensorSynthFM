# SensorSynth FM — Claude Code Instructions

## Project Overview
An iPad FM synthesizer with passive environment sensing as modulation.
The iPad sits on a table. Camera, microphone, and accelerometer absorb
the surrounding environment and use it to modulate the FM synthesis
parameters in real time. Read masterplan.md for the full product vision.

## Before Every Task
1. Read tasks.md to find the current task
2. Read the relevant domain .md file (fm_engine.md, sensor_mapping.md, etc.)
3. Ask me if anything is unclear BEFORE writing code
4. Tell me what you are about to do in plain language before doing it

## Tech Stack
- Swift / SwiftUI (iOS 17+, iPad primary)
- AudioKit for FM synthesis and audio engine
- CoreMotion for accelerometer, gyroscope, barometer
- AVFoundation for microphone input
- Vision framework for camera optical flow
- MPE-compliant MIDI implementation

## Audio Thread Safety — CRITICAL
These rules must never be violated. Flag any violation immediately.

- NEVER allocate memory inside audio render callbacks
- NEVER acquire locks inside audio render callbacks
- NEVER call blocking functions in audio callbacks
- NEVER use Swift classes with reference counting in the audio thread
- Use atomic values (Swift Atomics or simple @propertyWrapper) for cross-thread parameter passing
- Use AudioKit's AUParameter tree for all parameter updates from the UI thread
- If unsure whether something is audio-thread safe, ask before implementing

## Threading Model
- Audio thread: AudioKit render callback — never block, never allocate
- Sensor thread: CoreMotion background queue — 100-200 Hz, smooth values before passing to audio
- Vision thread: Background dispatch queue — 10-15 FPS optical flow
- UI thread: SwiftUI main thread — only reads smoothed values, never writes directly to audio

## MPE Requirements
- Each touch point is an independent voice with its own channel
- Per-voice: pitch bend (Y-axis movement), pressure (touch force), slide (X-axis movement)
- Voice allocation must be designed for MPE from the start — not retrofitted

## Communication Style
- Explain changes in plain language, not code jargon
- After every change, tell me WHAT to test and WHAT to listen for
- If you encounter an audio architecture decision with multiple valid approaches,
  explain the options and their trade-offs — let me decide
- Never assume I know what a code term means — define it if you use it

## Project File Map
- masterplan.md     — product vision and design philosophy
- fm_engine.md      — FM synthesis architecture and parameter specs
- sensor_mapping.md — sensor-to-parameter mapping definitions
- design_guidelines.md — visual design language
- tasks.md          — current sprint tasks (check this first)
- audio_bugs.md     — running log of audio issues
- workflow.md       — tool allocation across Claude, Gemini, Xcode Agent

## Multi-Tool Context
This project uses multiple AI tools. You (Claude Agent in Xcode) handle
implementation: writing Swift code, building, testing, and verifying previews.
Gemini 3.1 Pro (via Antigravity) handles large-context research and design review.
Claude in Cowork handles project documentation and orchestration.

If you encounter an architectural decision that needs broader context (e.g.,
choosing between AudioKit approaches, or UI design patterns), flag it for
the developer rather than making the call alone. The developer may want to
consult Gemini or Cowork before proceeding.

## Lessons Learned
(This section grows as we work — add entries here when mistakes are made)
- [Empty — will be populated during development]
