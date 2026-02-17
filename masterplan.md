# SensorSynth FM — Master Plan

## What This Is
SensorSynth FM is an iPad FM synthesizer that uses the device's built-in
sensors as passive modulation sources. The core idea: the iPad sits on a
table in its normal operating position, and the world around it becomes
part of the sound. No picking it up, no tilting, no deliberate gesturing
required — unless you want to.

## The Passive Sensing Paradigm
Most sensor-based music apps require the user to actively move the device.
SensorSynth FM inverts this. The sensors absorb the environment:

- Camera watches the user dancing, swaying, or moving nearby
- Microphone picks up ambient sound — music, conversation, room noise
- Accelerometer detects table vibrations — footsteps, bass frequencies, taps
- Gyroscope measures subtle shifts in the surface the iPad rests on

None of this requires high resolution. Small, continuous, organic changes
in the environment create small, continuous, organic changes in the sound.
The result is that no two performances of the same patch are identical,
even without the performer doing anything deliberately.

## Three-Tier Interaction Model
Tier 1 — Passive: iPad on table, environment modulates the sound.
  User is not touching the device at all.

Tier 2 — Responsive: User's natural movement (dancing, conducting, leaning)
  is detected by camera and mic. No deliberate iPad interaction needed.

Tier 3 — Active: User picks up the iPad, tilts it, gestures deliberately.
  Full sensor range available for expressive performance.

All three tiers work simultaneously and blend naturally.

## The Touch Interface
The performance surface uses an XY hybrid model:
- X axis = time (position in phrase or sequence)
- Y axis = pitch (continuous, not snapped to keys)
- Touch pressure = per-note expression (MPE)
- Finger movement after initial contact = per-note modulation (MPE slide)

This design acknowledges that touchscreen interaction is inherently imprecise
and turns that imprecision into expressiveness rather than fighting it.

## FM Synthesis Architecture
Inspired by the Elektron Digitone:
- 4 operators: A1, A2, B1, B2
- 8 routing algorithms
- Per-operator: ratio, level, feedback, waveform, detune, envelope
- Post-FM multimode filter (LP/HP/BP)
- 8-voice polyphony, MPE-aware (each voice independent)

## Sensor Modulation Capture
A key feature: users can record a segment of sensor modulation data,
trim it, and loop it as a repeatable modulation source. This turns a
fleeting environmental moment (a specific crowd energy, a particular
room acoustic) into a controllable, repeatable performance element.

## Design Philosophy
Inspired by Fors.fm's approach to complex tools: every element earns its
screen space. The UI must tame the complexity of FM synthesis and sensor
routing without hiding the power. Users should be able to create at their
highest level in the shortest time possible.

Dark minimal aesthetic. Monospaced type for numerical values. Orange and
blue accent system. Dense but never cluttered.

## Target Users
Primary: Electronic musicians comfortable with synthesis who want a
  genuinely new kind of expressive instrument.
Secondary: Sound designers and experimental musicians exploring
  environmental and generative sound.
Tertiary: Curious non-musicians drawn to the passive interaction model.

## Success Criteria for MVP
- FM engine with all 8 algorithms, 8-voice MPE polyphony
- Passive sensing from all four sources (camera, mic, accel, gyro)
- Sensor modulation assignment matrix
- Sensor capture and loop
- Basic step sequencer (16 steps, 4 tracks)
- Preset save/load
- App Store submission ready

## Context
This project is also a passion project and design research artifact
for an MS UX program at Kent State University, fall 2026 deadline.
The interaction design questions it raises — how to make complex synthesis
accessible through passive environmental context — are genuine research
contributions to the HCI and music technology fields.
