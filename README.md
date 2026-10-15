# SensorSynthFM

A playable iPad FM instrument that uses touch and environmental sensing to shape sound. Designed by James Dishman as his Kent State MS User Experience capstone, with AI-assisted implementation and review.

**[See the physical-iPad demonstration and project →](https://nomadjames.com/building/sensorsynth/)**

[Current build synopsis](https://nomadjames.com/building/sensorsynth/current/) · [Dated build history](https://nomadjames.com/building/sensorsynth/process/) · [Desk research](https://nomadjames.com/building/sensorsynth/desk-research/)

## Status and branch guide

This is working audio software, not a collection of SwiftUI mockups. **AudioKit is integrated**, including on `main`. The playable note-entry and Instrument work lives on review branches and is not all merged into `main`.

| Branch | What it contains |
| --- | --- |
| [`main`](https://github.com/nomadjames/SensorSynthFM/tree/main) | The earlier AudioKit FM oscillator and live sensor-to-FM test build. Not the latest playable instrument. |
| [`work/ssfm-hold-note-feedback-20260920`](https://github.com/nomadjames/SensorSynthFM/tree/work/ssfm-hold-note-feedback-20260920) | The September physical-iPad note-entry and Hold build shown in the public demonstration. |
| [`work/ssfm-instrument-foundation-20261006`](https://github.com/nomadjames/SensorSynthFM/tree/work/ssfm-instrument-foundation-20261006) | The October Instrument review candidate, adding amplitude-envelope and filter controls. Native and participant qualification remain separate from code availability. |

The public demonstration is labeled with its build date. It is evidence of the September physical build, not a claim that every later change has passed hardware or outside-user evaluation.

## What the playable branches do

- Start notes directly from a landscape touch surface in Quantized or Freehand mode.
- Give active touches independent pitch control and support held, editable chords.
- Show active-finger reticles and persistent markers for held notes.
- Use AudioKit FM voices while sensor input shapes timbre.
- Keep sensor routing available in a modulation Matrix.
- In the October Instrument candidate, expose amplitude-envelope and filter controls without replacing the native AudioKit audio graph.

The voice bank has ten slots. That is an implementation capacity, not a verified maximum stable polyphony claim under combined audio, sensor, and touch load.

## The design question

A synth can respond to the room and still be hard to play. SensorSynthFM puts direct note entry first and asks whether a musician can understand how touch, movement, and room energy affect the sound. The research and build history record where the mappings work, where the interface failed on hardware, and what still needs evaluation.

The current capstone is a bounded instrument proof. Outside-user comprehension and maximum stable polyphony remain open. MPE, a looper and sequence editor, patch generation, presets, AUv3, and Ableton integration are not claims about the verified build.

## Stack

- **Language:** Swift
- **Interface:** SwiftUI with native touch handling on the playable branches
- **Audio:** AudioKit, SoundpipeAudioKit, and AVFoundation
- **Sensors:** Core Motion and microphone input
- **Target:** iPad, landscape orientation

## Run a review build

Use a Mac with Xcode and an iPadOS SDK supported by the selected branch. For the October review candidate:

```sh
git clone --branch work/ssfm-instrument-foundation-20261006 https://github.com/nomadjames/SensorSynthFM.git
cd SensorSynthFM
open SensorSynthFM.xcodeproj
```

Let Xcode resolve the Swift package dependencies. Select the SensorSynthFM scheme and an iPad simulator or connected iPad, configure signing for a physical device, then build and run. Motion and room-input behavior need a real iPad; simulator execution cannot qualify those interactions.

To inspect the September demonstration build instead, select `work/ssfm-hold-note-feedback-20260920`. To inspect the earlier sensor test baseline, select `main`.

## Find the implementation

- [`SensorSynthFM/`](SensorSynthFM/): app and audio source for the selected branch.
- [`SensorSynthFM.xcodeproj/`](SensorSynthFM.xcodeproj/): Xcode project at the repository root.
- [`SensorSynthFMTests/`](SensorSynthFMTests/) and [`SensorSynthFMUITests/`](SensorSynthFMUITests/): test targets; their coverage varies by branch.
- [`docs/`](docs/): project documentation.
- [`masterplan.md`](masterplan.md), [`fm_engine.md`](fm_engine.md), and [`sensor_mapping.md`](sensor_mapping.md): design and architecture records. Older planning documents describe a broader product vision, not a list of completed features.

## Research and authorship

James owns the musical judgment, UX direction, and evaluation. AI collaborators support implementation, review, and research synthesis. Related work: [Ableton UX evaluation suite](https://nomadjames.com/portfolio/ableton-evaluation-suite/).

*README refreshed with AI assistance, October 15, 2026.*

## License

MIT
