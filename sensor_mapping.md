# SensorSynth FM — Sensor Mapping Definitions

## Sensor Sources

### Accelerometer (CoreMotion)
- Update rate: 100 Hz (configurable up to 800 Hz — 100 Hz is sufficient)
- Raw range: -2g to +2g per axis (X, Y, Z)
- When iPad is flat on table, Z is approximately -1g (gravity)
- Useful signal for passive sensing: magnitude of deviation from resting state
- Resting baseline: X≈0, Y≈0, Z≈-1g
- Table tap signature: sharp spike (0.1–0.5g) followed by decay

### Gyroscope (CoreMotion)
- Update rate: 100 Hz
- Raw range: radians/second
- Sensitive to table vibrations at lower frequencies
- iPad flat on table: all axes near 0 at rest

### Camera Optical Flow (Vision framework)
- Frame rate: 10–15 FPS (balance CPU vs responsiveness)
- Output: motion magnitude (scalar 0–1) and direction vector
- Front camera preferred (sees user)
- Useful signal: rolling average over 3–5 frames to smooth noise

### Microphone Amplitude (AudioKit)
- Output: RMS amplitude, 0 to 1
- Useful signal: smoothed with ~50ms attack, ~200ms release
- Also: spectral analysis — low band (20–250 Hz), mid (250–2kHz), high (2k–20kHz)

### Gyroscope / Barometer (future)
- Barometer: slow changes (~1 Hz), useful for very slow macro modulation
- Not priority for MVP

---

## Scaling Guidelines
All sensor values should be normalised to 0–1 before routing to destinations.
Apply smoothing BEFORE the audio thread. Raw sensor data is too jittery.

Recommended smoothing:
- Accelerometer: low-pass filter, cutoff ~5 Hz (smooth table taps to ~200ms decay)
- Gyroscope: low-pass filter, cutoff ~3 Hz
- Camera: rolling average, 4 frames (~300ms at 15 FPS)
- Microphone amplitude: attack 30ms, release 150ms

---

## Prototype Findings (Max/MSP + ZIG SIM)
(Update this section as you prototype mappings in Max/MSP)

| Sensor Source       | Destination      | Scale   | Notes                          |
|---------------------|------------------|---------|--------------------------------|
| Accel magnitude     | Mod Index        | 0–4     | Table tap creates FM bite      |
| Camera motion       | Carrier ratio    | 0–2     | Slow motion only (rolling avg) |
| Mic amplitude       | Filter cutoff    | 200–4k  | Room volume opens filter       |
| Mic low band        | Operator B level | 0–0.6   | Bass in room = more FM depth   |
| Gyro magnitude      | Filter resonance | 0–0.4   | Subtle table vibration         |

---

## Mapping Rules
- One sensor source can map to multiple destinations
- One destination can receive from multiple sources (values sum, clamped to range)
- Minimum meaningful movement threshold: ~0.05 normalised (ignore micro-jitter)
- Maximum useful range per destination: see fm_engine.md parameter ranges

## Open Questions
- [ ] Should mappings be bipolar (positive and negative modulation) or unipolar?
- [ ] How to handle multiple active mappings summing — simple add or weighted mix?
- [ ] Should the user be able to invert a mapping (high sensor value = low param)?
