# SensorSynth FM — Audio Bug Log

## How to Use This File
When you hear something wrong, describe it here before asking Claude Code
to fix it. The more specific your description, the faster it gets fixed.

Good description: "When I tap the table hard, there is a short click/pop
sound about 100ms after the FM timbre changes. It happens every time."

Bad description: "It sounds weird when I tap."

---

## Template for New Bugs

### Bug [number]: [short name]
**Date:**
**When it happens:**
**What I hear:**
**How to reproduce:**
**Expected:**
**Status:** Open / Fixed / Won't Fix

---

## Active Bugs
(None yet — project in early development)

---

## Fixed Bugs
(None yet)

---

## Known Audio Risks to Watch For
These are common issues in iOS audio development. Log them here if encountered.

- **Clicks on note onset**: usually a missing attack envelope or audio thread
  doing something it should not (allocation, locking)
- **Clicks on note release**: usually envelope releasing too fast, or voice
  being deallocated before release completes
- **Sensor-driven zippering**: stepping artifacts when sensor values change
  too fast — fix with parameter smoothing
- **CPU spikes causing dropouts**: audio engine cannot keep up — check for
  work being done on audio thread that should be offloaded
- **Latency between sensor input and sound change**: check CoreMotion
  update rate and smoothing window — may be too long
