# SensorSynth FM

An iPad FM synthesizer that uses environmental sensing as a live modulation source.

> **Status:** Early development — UI mockups complete, audio engine in progress.

---

## Concept

SensorSynth FM is a performance instrument for iPad built around a simple idea: the environment around the player should be part of the sound. Rather than treating the iPad as a static touch interface, SensorSynth FM uses the device's awareness of its surroundings as a continuous, living modulation layer — without the player having to think about it.

The touch interface is built around an XY surface where time moves left to right and pitch moves up and down. It supports MPE (MIDI Polyphonic Expression), giving each finger an independent expressive voice. Underneath is a four-operator FM engine with eight routing algorithms inspired by classic FM hardware.

---

## Features (Planned)

- 4-operator FM synthesis engine with 8 configurable algorithms
- 8-voice MPE with per-voice pitch, pressure, and slide
- Environmental sensing as modulation — passive, responsive, and active tiers
- 11 sensor sources routable to 6 synthesis destinations
- 16-step sequencer with per-step parameter locks
- Sensor modulation capture and loop playback
- Dark minimal UI designed for live performance

---

## Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Audio:** AudioKit
- **Platform:** iPadOS, landscape orientation
- **Min target:** iOS 17 / A12 chip (M-series recommended for full feature set)

---

## Project Structure

```
SensorSynthFM/
├── SensorSynthFM/          # Xcode project
│   ├── ContentView.swift       # Tab navigation
│   ├── PerformanceView.swift   # Main performance screen
│   ├── FMEngineView.swift      # FM algorithm and operator editor
│   ├── SensorModulationView.swift  # Sensor routing matrix
│   └── SynthColors.swift       # Shared color palette
├── CLAUDE.md               # AI session instructions and audio rules
├── masterplan.md           # Full product vision
├── tasks.md                # Current sprint and backlog
├── fm_engine.md            # FM architecture specification
├── sensor_mapping.md       # Sensor sources, ranges, smoothing
├── design_guidelines.md    # Color, typography, layout system
└── audio_bugs.md           # Known issues and audio risk log
```

---

## Running the Project

1. Clone the repo
2. Open `SensorSynthFM/SensorSynthFM.xcodeproj` in Xcode
3. Select an iPad simulator or connected device
4. Build and run

AudioKit is not yet integrated — the current build contains SwiftUI mockups only.

---

## Author

James Dishman — UX Design graduate student
Building this as a research project at the intersection of interaction design and music technology.

---

## License

MIT
