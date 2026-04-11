# Documentation Drift and Source of Truth

SensorSynth FM has multiple project descriptions that do not fully agree.

That is normal for an evolving project, but it becomes dangerous when nobody writes down which documents describe current reality versus future ambition.

## Practical hierarchy
For current implementation truth, trust the live Swift files first.

For current build strategy and prioritization, trust:
- build-brief.md
- familiarization-index.md
- implementation-packet-sensor-thesis-demo.md

For long-range product intent, treat documents like the master plan and deeper spec docs as aspirational unless they are confirmed by current code.

## Concrete drift found
The old README still described the app as mockup-only and said AudioKit was not yet integrated.

That is no longer true.

The project now contains a real FM prototype and sensor-routing code. The more accurate description is that the integrated thesis-demo lane exists but is not yet the default app surface.

## Why this page matters
Without a source-of-truth rule, ambitious projects become impossible to discuss cleanly. Everyone ends up talking about a different version of the project.
