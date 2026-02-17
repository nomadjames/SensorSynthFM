# SensorSynth FM — FM Engine Specification

## Architecture Overview
4-operator FM synthesis inspired by Elektron Digitone.
Operators: A1, A2, B1, B2
Algorithms: 8 routing configurations
Polyphony: 8 voices, MPE-aware (each voice fully independent)

## Operator Structure
Each operator has:
- Ratio (coarse): 0.5 to 16.0 (integer and half-integer steps)
- Ratio (fine): -50 to +50 cents
- Level: 0 to 99
- Feedback: 0 to 7 (self-modulation amount)
- Waveform: Sine, Triangle, Square, Sawtooth (sine is primary)
- Detune: -50 to +50 cents (for unison/chorus effects)
- Envelope: ADSR per operator
  - Attack:  0.001s to 10s
  - Decay:   0.001s to 10s
  - Sustain: 0 to 1 (level)
  - Release: 0.001s to 30s

## Algorithms (Operator Routing)
A = carrier group (outputs audio), B = modulator group
Connections listed as modulator -> carrier:

1. B2->A1, B1->A1, A2->A1         (all modulate A1, one carrier)
2. A2->A1, B2->B1                  (two parallel stacks)
3. B1->A1, B2->A2                  (two parallel stacks, variant)
4. A2->A1->output, B2->B1->output  (two chains)
5. B2->B1->A1, A2->A1             (mixed)
6. B2->A1, B2->B1                  (B2 modulates both carriers)
7. A2->A1                          (simple two-op, B1+B2 free carriers)
8. All four are carriers            (pure additive, no FM)

## Post-FM Processing
- Multimode Filter: LP / HP / BP
  - Cutoff: 20 Hz to 20 kHz
  - Resonance: 0 to 1 (self-oscillation at high values)
  - Drive: 0 to 1 (pre-filter saturation)
- Output level: 0 to 1
- Pan: -1 to +1

## AudioKit Implementation Notes
- Use AudioKit FMOscillator as the base building block
- One FMOscillator per operator per voice = 32 oscillators total at full polyphony
- Consider CPU budget: test on A12 iPad before assuming performance
- Parameter updates must go through AUParameter tree (audio thread safe)
- Voice allocation: round-robin for non-MPE, channel-assigned for MPE

## Parameter Ranges for Sensor Modulation
Good targets for sensor modulation (smooth, musically useful ranges):
- Modulation Index: 0 to 10 (primary FM timbre control)
- Carrier Ratio: 0.5 to 8 (pitch character)
- Filter Cutoff: 200 Hz to 8 kHz (sweetspot for sensor modulation)
- Filter Resonance: 0 to 0.7 (avoid self-oscillation from sensors)
- Operator Level (B1, B2): 0 to 0.8 (modulation depth)

## Open Questions
- [ ] Should ratio be continuous or stepped? (Digitone uses stepped, but continuous may suit sensor modulation better)
- [ ] Velocity sensitivity per operator or global?
- [ ] Pitch bend range: standard 2 semitones or wider for MPE expressiveness?
