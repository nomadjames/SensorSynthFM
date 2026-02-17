# SensorSynth FM — Design Guidelines

## Design Philosophy
Inspired by Fors.fm: complex tools made approachable through
considered layout and visual hierarchy. Every element earns its
screen space. The UI tames FM synthesis complexity without hiding
the power underneath. Users should reach peak creativity as fast
as possible.

Dark and functional. Not decorative. Not minimal to the point of
opacity. Dense but never cluttered.

---

## Color System

### Backgrounds
- App background:    #1A1A1A  (very dark grey, not pure black)
- Surface:          #282828  (slightly lifted panels, headers)
- Surface raised:   #383838  (buttons, inactive elements)

### Accents
- Primary accent:   #E8913A  (warm orange — primary interactive, active states)
- Secondary accent: #2E6B9E  (blue — secondary controls, operator B group)
- Sensor green:     #2D8B4E  (sensor activity, passive sensing indicators)

### Text
- Primary text:     #E0E0E0  (body text, values)
- Secondary text:   #808080  (labels, inactive, metadata)
- Dividers:         #424242  (structural separators)

### Semantic Colors
- Playing/active:   accent orange
- Sensor active:    sensor green
- Error/warning:    #C0392B  (red, used sparingly)
- Recording:        system red

---

## Typography

All numerical readouts: SF Mono (system monospaced)
All UI labels: SF Pro (system default)
All parameter labels: SF Mono, 8–9pt, secondary text color, UPPERCASE
All numerical values: SF Mono, varies by context (7–16pt)
Patch names: SF Pro medium, 14pt, primary text color

Avoid custom fonts. System fonts render crisply at small sizes on iPad.

---

## Layout Principles

### Primary orientation: Landscape
All screens designed landscape-first. Portrait should be supported
but is secondary.

### Touch targets
Minimum 44pt for all interactive elements.
Performance-critical controls (macro knobs, step buttons during play):
aim for 52pt+ to reduce missed taps during performance.

### Information density
High density is acceptable. Clutter is not.
Rule: if an element cannot be explained in one word, it needs a label.
Rule: numerical values always visible (no "hover to reveal" on iPad).

### Grid
No strict grid enforced, but consistent internal spacing:
- Panel padding: 12pt
- Element spacing within panels: 8pt
- Micro spacing (label to value): 3–4pt

---

## Component Patterns

### Knobs
- Circular arc indicator, 280-degree sweep
- Gap at bottom (6 o'clock = minimum, clockwise = increase)
- Color: accent orange for primary, blue for secondary, green for sensor-linked
- Label above, value below
- Minimum size: 38pt diameter for performance controls

### Step Sequencer Cells
- Rounded rectangle, 22pt height
- Active + selected track: accent blue
- Active + other track: divider grey
- Currently playing: accent orange
- Inactive: surface raised

### Sensor Activity Bars
- Vertical bars, filled from bottom
- Color matches sensor type (green for motion, blue for camera, orange for mic)
- Always visible in transport strip, compact (18pt wide, 20pt tall)

### Algorithm Diagram
- Operator nodes: rounded rectangle, colored by group (orange=A, blue=B)
- Modulation connections: thin grey lines with directional flow
- Output connections: green lines
- Selected operator: slightly brighter fill

---

## Screen-Specific Notes

### Performance View
- XY surface takes ~60% of landscape width — this is the primary real estate
- Sequencer is compact but always visible alongside the surface
- Macro knobs at bottom must be large enough to grab mid-performance
- Transport strip must be thin — does not compete with playing area

### FM Engine View
- Algorithm diagram is the visual anchor — make it readable at a glance
- Operator detail panel appears below/beside algorithm, not in a separate screen
- ADSR shown as vertical bars (compact, clear)

### Sensor Modulation View
- Matrix is the centerpiece — rows = sources, columns = destinations
- Active mappings should be immediately obvious (filled cell, colored)
- Sensor readouts should feel "live" — subtle animation on active sensors
- Capture panel: record button should be large enough to tap reliably

---

## Interaction Principles

### Feedback
Every touch produces immediate visual feedback. No 100ms+ delays.
Step cells toggle instantly. Knob values update as finger moves.

### Gestural Performance Surface (XY Pad)
Touch trails: show faint path of recent touch positions (< 500ms decay)
Multiple touches: each voice rendered with its own color circle
Pressure indicator: outer ring size represents touch pressure / MPE pressure

### Progressive Disclosure
Expert controls (fine ratio, operator detune) are present but
visually subordinate to primary parameters.
No hidden menus for core parameters.
