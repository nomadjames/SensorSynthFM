# SensorSynth FM -- Figma Make Prompt

Paste the following into Figma Make. The prompt is designed to produce high-fidelity iPad interface mockups for all three screens of the app.

---

## THE PROMPT

Design three iPad app screens in landscape orientation (2388 x 1668 px or equivalent iPad Pro 12.9" resolution) for an FM synthesizer called SensorSynth FM. This is a professional music performance app. The design language is dark, dense, and functional, inspired by hardware synths like the Elektron Digitone and software like Fors.fm. Every element earns its screen space. Nothing decorative. Nothing hidden.

### Global Design Tokens

**Backgrounds:**
- App background: #1A1A1A (very dark grey, not pure black)
- Surface/panels: #282828 (slightly lifted)
- Raised elements/buttons: #383838

**Accents:**
- Primary (interactive, active states): #E8913A (warm orange)
- Secondary (operator B group, envelopes): #2E6B9E (blue)
- Sensor activity: #2D8B4E (green)
- Error/recording: #C0392B (red, used sparingly)

**Text:**
- Primary text: #E0E0E0
- Secondary/labels: #808080
- Dividers: #424242

**Typography:**
- All numerical readouts and parameter values: monospaced font (SF Mono style), 7-9pt for labels, 14-16pt for large values
- UI labels: UPPERCASE, monospaced, 8-9pt, secondary text color
- Patch names: medium weight, 14pt, primary text color
- No custom or decorative fonts

**Component patterns:**
- Knobs: circular arc indicator, 280-degree sweep, gap at 6 o'clock (minimum), clockwise increases value. Label above, value inside or below. Orange for primary controls, blue for envelope/secondary, green for sensor-linked parameters. Minimum 38pt diameter.
- Touch targets: minimum 44pt, performance-critical controls 52pt+
- Panel padding: 12pt, element spacing: 8pt, micro spacing (label to value): 3-4pt
- All panels separated by 1px #424242 divider lines
- Rounded corners: 3-6pt on small elements, 6-8pt on panels

---

### SCREEN 1: Performance View (primary screen)

This is where the user plays the instrument. It must feel like a hardware synth's live performance mode.

**Layout (top to bottom):**

1. **Transport strip** (48pt tall, #282828 background):
   - Left: Play/Stop button (rounded rect, #383838 background, play icon in primary text, orange when playing)
   - BPM display: label "BPM" in 8pt secondary text above, value "124" in 16pt monospaced primary text below
   - Vertical 1px divider
   - Patch name: label "PATCH" in 8pt secondary above, name "Passive Field 01" in 14pt medium weight below
   - Right side: 4 sensor activity indicators in a row. Each is a small vertical bar (18px wide, 20pt tall) filled from bottom with its sensor color (green for ACC and GYR, blue for CAM, orange for MIC). 7pt monospaced label below each bar. Show them at varying fill levels to look "live."

2. **Main content area** (split horizontally):

   **Left 60%: XY Performance Surface** (#1A1A1A background):
   - Horizontal grid lines suggesting pitch intervals (24 lines for 2 octaves), every 12th line slightly brighter. Very subtle, #424242 at 25% opacity, octave lines at 70%.
   - Vertical grid lines suggesting time divisions (16 lines). Same subtle treatment.
   - Bottom-right corner: small "TIME" arrow label. Left side: small "PITCH" arrow label (rotated 90 degrees).
   - 3 mock touch points at different positions: each is a small filled circle (11pt) with a larger pressure-indicating ring around it (varying sizes, 30-50pt diameter). Use different accent colors for each voice (orange, blue, green). Number labels 1, 2, 3 inside each dot.
   - Top-right corner: "MPE" badge (orange text on orange/12% opacity background, rounded rect, 9pt bold monospaced)

   **Right 40%: Sequencer Panel**:
   - Track selector row: 4 buttons labeled T1, T2, T3, T4. Selected track has orange background with dark text, others have #383838 background with secondary text. 11pt semibold monospaced.
   - Step grid: 4 rows (one per track) of 16 step cells. Each cell is a small rounded rectangle (22pt height). Color coding: active step on selected track = #2E6B9E blue, active step on other tracks = #424242, currently playing step = #E8913A orange, inactive = #383838. Step numbers 1-16 above in 7pt secondary text.
   - Parameter locks row: label "PARAM LOCKS" in 8pt bold secondary, then small chip buttons for NOTE, VEL, MOD, FILT in #383838 with 8pt secondary text.

3. **Macro strip** (84pt tall, #282828 background):
   - 6 arc knobs in a row, evenly spaced: CUTOFF, RESO, MOD, FDBK, REVERB, SENS
   - Each knob: 38pt diameter, orange arc for the first 5, green arc for SENS (sensor-linked). 7pt label above, MIDI value (0-127) inside in 7pt secondary text.
   - After the 6 knobs, a vertical divider, then a "RND" randomize button with a dice icon (SF Symbol style) in orange.

---

### SCREEN 2: FM Engine View

This is the sound design screen where users shape the FM synthesis parameters.

**Layout:**

1. **Header bar** (48pt, #282828): "FM ENGINE" in 11pt bold orange monospaced, dot separator, patch name in 11pt secondary text. Left-aligned.

2. **Left panel (36% width):**

   **Algorithm section:**
   - Label "ALGORITHM" in 9pt bold secondary, right-aligned "3 of 8" in 9pt orange
   - Algorithm diagram (130pt tall): 4 operator nodes arranged in a 2x2 grid. A1 top-left, A2 bottom-left (both orange, A2 slightly lighter), B1 top-right, B2 bottom-right (both blue, B2 slightly lighter). Each node is a 44x28pt rounded rectangle with the operator name in 11pt bold white monospaced text centered inside. Draw thin grey connection lines between nodes showing modulation routing for algorithm 3 (B1 to A1, B2 to A2). Draw green output lines from carrier operators (ones not acting as modulators) going down to an "OUT" label at the bottom.
   - Algorithm selector: 8 small numbered buttons (1-8) in a row, with left/right chevron buttons on each end. Selected algorithm has orange background, others #383838.

   **Operator picker** (below algorithm):
   - 4 cells in a horizontal row: A1, A2, B1, B2. Each has a small colored circle (8pt) above the name. Selected operator has #383838 background. 11pt medium monospaced text.

3. **Right panel (64% width):**

   **Operator detail** (upper portion):
   - Header: colored dot + "OPERATOR A1" in 11pt bold monospaced, right side: waveform icon + "SIN" in a #383838 chip
   - 7 parameter knobs in a grid row: RATIO, LEVEL, FDBK, ATK, DEC, SUS, REL. First 3 knobs use orange arcs, last 4 (envelope) use blue arcs. Each knob 42pt diameter, label above in 7pt secondary, value inside in 7pt secondary. Show realistic values: Ratio "2.60", Level "80", Fdbk "2", Atk "0.02", Dec "0.30", Sus "0.60", Rel "0.40".
   - ADSR visual: small vertical bar chart showing the 4 envelope stages. Each bar is a 26x52pt rounded rect, blue fill from bottom proportional to value. Labels ATK, DEC, SUS, REL in 7pt below each bar. "ENV" label to the left.

   **Filter panel** (lower portion, #282828 background):
   - "FILTER" label in 9pt bold secondary
   - Filter type selector: 3 small buttons LP, HP, BP. Selected (LP) has orange background. 10pt monospaced.
   - 3 knobs: CUTOFF (value "7k"), RESO (value "0.28"), DRIVE (value "0.12"). All orange arcs, 42pt.

---

### SCREEN 3: Sensor Modulation View

This is where users see live sensor data, assign sensor-to-parameter mappings, and capture sensor loops.

**Layout:**

1. **Header bar** (48pt, #282828): "SENSOR MODULATION" in 11pt bold green monospaced. Right side: green dot + "PASSIVE SENSING ACTIVE" badge (green text on green/10% background, rounded rect).

2. **Three-column layout:**

   **Left column (28%): Sensor Readouts**
   - "SOURCES" label in 9pt bold secondary
   - 11 rows, one per sensor source: ACCEL X, ACCEL Y, ACCEL Z, GYRO X, GYRO Y, GYRO Z, CAM MOTION, MIC AMP, MIC LOW, MIC MID, MIC HI
   - Each row: small colored activity dot (5pt, lit when level > threshold), source name in 9pt monospaced primary text, horizontal level bar (48pt wide, 10pt tall, filled proportionally with sensor color), numerical value in 8pt secondary text. Rows separated by 0.5px dividers.
   - Color coding: accelerometer/gyroscope rows use green, camera rows use blue, microphone rows use orange.

   **Center column: Modulation Matrix**
   - Column headers across top: MOD IDX, CARRIER, FDBK, CUTOFF, RESO, LEVEL in 8pt secondary monospaced, centered.
   - Row labels on left matching the 11 sensor sources in 8pt secondary monospaced.
   - Grid of cells (11 rows x 6 columns). Each cell is 30pt tall. Inactive cells: #383838 at 40% opacity. Active mappings: sensor-colored background at 25% opacity with a small 10pt filled rounded square in the center at 90% opacity. Show 4 active mappings: ACCEL X to MOD IDX, CAM MOTION to CARRIER, MIC AMP to CUTOFF, MIC HI to LEVEL. Cell borders: 0.5px #424242 at 40%.

   **Right column (22%): Capture Panel**
   - "CAPTURE" label in 9pt bold secondary
   - Large record button: full-width rounded rect with a 12pt red circle icon + "RECORD" in 10pt bold secondary. Border: 1px #424242. When recording state: red circle, "STOP" text, red tint on background.
   - Divider
   - "LOOPS (2)" label in 8pt secondary
   - 2 loop cards, each in a #282828 rounded rect:
     - Header row: loop name ("Loop 1") in 9pt medium monospaced, duration ("4.2s") in 8pt secondary right-aligned
     - Source label ("ACCEL X") in 7pt blue monospaced
     - Waveform thumbnail: 28pt tall #383838 rounded rect with a blue sine-like waveform drawn inside
     - Control row: "LOOP" toggle button (green text + checkmark when active, #383838 chip), "ONCE" button (#383838 chip), trash icon far right

---

### Navigation

Include a bottom tab bar consistent across all three screens:
- 3 tabs: PERFORM (piano keys icon), FM ENGINE (waveform circle icon), SENSORS (sensor/radio wave icon)
- #282828 background, 1px #424242 divider on top
- Selected tab: orange icon + orange label. Unselected: #808080 icon + text
- Icons 18pt, labels 9pt medium monospaced
- Vertical padding 10pt

---

### Key Design Notes
- This is a PROFESSIONAL music app. It should look like it belongs alongside Moog Model 15, Animoog, or Korg Gadget on the App Store. Dense, precise, technical.
- No gradients, no shadows, no blur effects. Flat, functional surfaces.
- The color system is strict: orange = primary interactive, blue = secondary/envelope/operator B, green = sensor/environmental, red = recording/error only.
- Every numerical value must be visible at all times. No hover states, no hidden info. This is an iPad touch instrument.
- Landscape orientation only for these mockups.
