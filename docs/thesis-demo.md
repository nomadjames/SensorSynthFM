# Thesis Demo Definition

The next milestone is not the full product. It is a bounded thesis demo.

## In one sentence
A one-screen iPad prototype where passive or lightly active sensing audibly and visibly shapes FM timbre in a way that feels musical, intentional, and easy to explain.

## Why this is the right target
SensorSynth FM already has enough ambition. The real question now is whether the interaction survives contact with reality.

## Required behaviors
The thesis demo should:
- boot into the integrated sensor-plus-FM screen
- start audio reliably
- show live sensor activity
- route 2 to 3 sensor sources into clearly named FM targets
- let the performer toggle mappings on and off
- produce audible differences that are obvious but not obnoxious
- make the cause-and-effect legible on the screen

## Acceptance checks
- table tap or surface vibration changes timbre in a repeatable way
- ambient sound changes at least one parameter in a way that is audible but controlled
- device movement changes at least one parameter without ugly jumps
- when mappings are off, the sound is stable
- when one mapping is on, the result is understandable
- when multiple mappings are on, the interaction is still demoable rather than chaotic

## Anti-goals for this milestone
Not yet:
- sequencer work
- preset browser
- camera-first interaction
- full MPE architecture
- store-readiness concerns

## Current best lane
Use the existing SensorFMTestView plus SensorFMBridge as the thesis-demo harness. The immediate implementation step is simply to activate and validate it.
