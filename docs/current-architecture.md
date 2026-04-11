# Current Architecture

## What is already in the repo
The current codebase already contains:
- a real AudioKit FM prototype
- a SensorManager for live input collection
- a SensorFMBridge for mapping sensor values into synthesis parameters
- a SensorFMTestView that appears to be the best integrated prototype path

## The important architectural truth
The codebase is ahead of the README and behind the master plan.

That means:
- the project is more real than the old public description suggests
- the project is less complete than the long-range design docs suggest

## Current bottleneck
The main problem is not building from scratch. The main problem is making the integrated path the active path, then testing it on real hardware.

## Design focus
The key design question is not precision. It is feel.

A small movement should create a musically intelligible change, not a chaotic spike. The system has to feel legible enough that a listener and performer can understand why the sound changed.

## Public rule of interpretation
When implementation truth and project docs disagree:
1. trust the live source files for current behavior
2. trust the build brief for current prioritization
3. treat broader design docs as product intent until verified in code
