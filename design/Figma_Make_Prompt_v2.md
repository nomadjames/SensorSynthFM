# SensorSynth FM -- Figma Make Prompt v2

**What changed from v1:** The Performance View has been completely redesigned around a full-screen touch surface with rim controls and an overlay sequencer. FM Engine and Sensor Modulation views have detail corrections from the v1 critique. You can paste all three screens at once, or paste them individually.

---

## THE PROMPT

Design three iPad app screens in landscape orientation (2388 x 1668 px, iPad Pro 12.9") for an FM synthesizer called SensorSynth FM. This is a professional music performance app. The design language is dark, dense, and functional, inspired by hardware synths like the Elektron Digitone and software like Fors.fm. Every element earns its screen space. Nothing decorative. Nothing hidden.

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

### SCREEN 1: Performance View (primary screen -- FULL SCREEN INSTRUMENT)

This screen is the instrument itself. The XY touch surface fills nearly the entire screen. The user holds the iPad in landscape and plays directly on the surface. Controls live on the narrow rim edges, optimized for thumb reach. The sequencer is a modal overlay, not a permanent panel.

**Design philosophy:** Think of this screen like a Roli Lightpad or Sensel Morph, not like a DAW. The touch surface IS the instrument. Everything else is secondary and pushed to the edges.

**Layout:**

1. **XY Performance Surface (fills ~88% of screen area, centered):**
   - Background: #1A1A1A
   - Horizontal grid lines suggesting pitch intervals (24 lines for 2 octaves). Every 12th line slightly brighter (#424242 at 70% opacity = octave boundaries). All other lines at #424242 at 20% opacity. Very subtle, never competing with touch points.
   - Vertical grid lines suggesting time divisions (16 lines). Same subtle treatment.
   - Bottom-right corner: tiny "TIME" label with right arrow, 7pt #808080 at 40% opacity.
   - Left edge (inside surface): tiny "PITCH" label with up arrow, rotated 90 degrees, 7pt #808080 at 40% opacity.
   - Top-right corner of surface: "MPE" badge (orange text, #E8913A at 100%, on orange at 8% opacity background, rounded rect, 9pt bold monospaced). This communicates that the surface supports MPE polyphonic expression.
   - 3 mock touch points at different positions across the surface:
     - Touch 1: position upper-left area. Small filled orange circle (11pt) with a larger semi-transparent orange ring around it (42pt diameter, 30% opacity). Number "1" in 8pt white inside the dot.
     - Touch 2: position center area. Blue dot (11pt) with blue ring (34pt, 30% opacity). Number "2".
     - Touch 3: position lower-right area. Green dot (11pt) with green ring (50pt, 30% opacity). Number "3".
     - The varying ring sizes represent different pressure/force levels. This is the core MPE visual language.
   - Left edge of surface: thin vertical sensor pulse bar (4pt wide, full height of surface). This bar has a subtle animated gradient showing sensor activity: green glow near the top (accelerometer), fading to blue in the middle (camera), fading to orange at bottom (microphone). Show it at about 40% brightness to look "alive" but not distracting.

2. **Top Rim (44pt tall, #282828 background, full width):**
   - Left cluster:
     - Play/Stop button: 44x44pt, #383838 rounded rect, play triangle icon in #E0E0E0, turns orange when playing
     - BPM: "124" in 14pt monospaced primary text, "BPM" in 7pt secondary above
     - 8pt gap
     - Patch name: "Passive Field 01" in 12pt medium primary text
   - Center:
     - Mode toggle: two adjacent buttons, "PERFORM" and "SEQUENCE". PERFORM has orange background with dark text (active state). SEQUENCE has #383838 background with secondary text. Each button 80x32pt, rounded rect, 9pt bold monospaced. This toggle switches between performance mode (current) and sequencer overlay mode.
   - Right cluster:
     - Settings gear icon, 24pt, #808080
     - Handedness toggle: small "L / R" button, 9pt monospaced, #383838 background. Whichever side is selected shows in orange. Currently showing "R" in orange (right-handed mode).

3. **Bottom Rim (60pt tall, #282828 background, full width):**
   - 6 arc knobs evenly spaced across the full width: CUTOFF, RESO, MOD DEPTH, FDBK, REVERB, SENS
   - Each knob: 38pt diameter, orange arc for first 5, green arc for SENS (sensor-linked). 7pt UPPERCASE label above each knob. Value (0-127 range) in 7pt secondary monospaced inside the arc.
   - Show realistic values: CUTOFF "78", RESO "32", MOD DEPTH "64", FDBK "12", REVERB "45", SENS "80"
   - After the 6 knobs: vertical 1px divider, then "RND" button with dice icon in orange, 38x38pt.

4. **Left Rim (44pt wide, transparent background, overlaying left edge of surface):**
   - This is a narrow vertical strip for thumb access.
   - Octave up/down: two stacked buttons, up arrow and down arrow, each 36x36pt, #383838 at 60% opacity, primary text icons. These shift the pitch range of the surface.
   - Below: "C3" label in 8pt monospaced secondary text (current base octave).

5. **Right Rim (44pt wide, transparent background, overlaying right edge of surface):**
   - Volume slider: vertical, 120pt tall, thin #424242 track with orange fill from bottom. Small 8pt "VOL" label above. Current value "85" in 7pt below.
   - Below: Sustain toggle button, "SUS" label, 36x36pt, #383838 at 60% opacity. Orange when active.

**NOTE about handedness:** The left and right rims are designed to mirror when the user toggles "L" in the handedness control. In left-handed mode, the octave buttons move to the right rim and the volume/sustain move to the left rim. This is not shown in the mockup but the layout should be symmetric enough that mirroring is visually natural.

---

**SCREEN 1B: Performance View -- Sequencer Overlay State**

This is the SAME screen as Screen 1, but with the "SEQUENCE" mode toggle active (orange) instead of "PERFORM". Show the XY surface dimmed to 40% brightness beneath the sequencer overlay.

**Overlay content (centered on screen, 80% width, 70% height, #282828 at 92% opacity, 8pt rounded corners, 1px #424242 border):**

- Top row: Track selector. 4 buttons: T1, T2, T3, T4. Selected track (T1) has orange background with dark text. Others #383838 with secondary text. 11pt semibold monospaced. Right-aligned: "PARAM LOCKS" label with chip toggles for NOTE, VEL, MOD, FILT in #383838 chips, 8pt text.

- Main grid: 4 rows (one per track) x 16 columns (steps). Each step cell is a rounded rectangle, 34pt tall, 8pt rounded corners.
  - Active step on selected track: #2E6B9E blue fill
  - Active step on other tracks: #424242 fill
  - Currently playing step (step 5): #E8913A orange fill
  - Inactive: #383838 fill
  - Step numbers 1-16 across the top in 7pt secondary text
  - Track labels T1-T4 on the left in 8pt colored text (T1 orange, T2 blue, T3 green, T4 #808080)

- Bottom row: Transport for sequencer context.
  - Play/Stop (same as rim, but larger 48pt for overlay context)
  - Step length selector: "1/16" chip in orange, with left/right arrows
  - Pattern length: "16" with left/right arrows
  - "CLEAR" button in #383838, "COPY" button in #383838, 9pt monospaced labels

- Close/dismiss: tapping "PERFORM" on the top rim mode toggle closes the overlay and returns to full performance surface.

---

### SCREEN 2: FM Engine View

This is the sound design screen where users shape the FM synthesis parameters.

**Layout:**

1. **Header bar** (48pt, #282828): "FM ENGINE" in 11pt bold orange monospaced, dot separator, patch name "Passive Field 01" in 11pt secondary text. Left-aligned.

2. **Left panel (36% width):**

   **Algorithm section:**
   - Label "ALGORITHM" in 9pt bold secondary, right-aligned "4 of 8" in 9pt orange monospaced
   - Algorithm diagram (140pt tall): 4 operator nodes in a 2x2 grid.
     - A1 top-left, A2 bottom-left: orange fills (#E8913A at 80% and 60%)
     - B1 top-right, B2 bottom-right: blue fills (#2E6B9E at 80% and 60%)
     - Each node: 48x30pt rounded rectangle, operator name in 11pt bold white monospaced centered inside
     - Connection lines: 2pt #808080 lines showing modulation routing for algorithm 4 (A2 modulates A1, B2 modulates B1). Use slight curves or right angles, not diagonal straight lines.
     - Output lines: 2pt #2D8B4E green lines from A1 and B1 going down to "OUT" labels. These are the carriers outputting audio.
   - Algorithm selector: 8 numbered buttons (1-8) in a row, each 30x26pt rounded rect. Selected (#4) has orange background with dark text. Others #383838 with secondary text. 10pt monospaced. Left/right chevron buttons on each end, 26x26pt.

   **Operator picker** (below algorithm, 12pt gap):
   - 4 cells in horizontal row: A1, A2, B1, B2
   - Each cell: 52x36pt rounded rect. Selected (A1): #383838 background with orange left border (3pt). Others: transparent with #424242 border.
   - Small colored dot (8pt) left of name. A-group dots orange, B-group dots blue.
   - 11pt medium monospaced text.

3. **Right panel (64% width):**

   **Operator detail** (upper 60%):
   - Header row: 8pt colored dot (orange for A1) + "OPERATOR A1" in 11pt bold monospaced primary text. Right side: waveform selector chip "SIN" in #383838 rounded rect with small sine wave icon, 9pt monospaced. Tappable to cycle waveforms.
   - 7 parameter knobs in a single row with even spacing:
     - RATIO (orange arc, value "2.60")
     - LEVEL (orange arc, value "80")
     - FDBK (orange arc, value "2")
     - ATK (blue arc, value "0.02")
     - DEC (blue arc, value "0.30")
     - SUS (blue arc, value "0.60")
     - REL (blue arc, value "0.40")
     - Each knob: 42pt diameter. 7pt UPPERCASE secondary label above. 7pt secondary monospaced value centered below the arc.
   - ADSR visualization (below knobs, 16pt gap):
     - "ENV" label left, 8pt secondary
     - 4 vertical bars side by side: ATK, DEC, SUS, REL. Each bar: 26pt wide, 56pt tall, #383838 background, blue (#2E6B9E) fill from bottom proportional to value. 7pt label below each bar in secondary text.
     - Show ATK at ~5% fill (fast attack), DEC at ~30%, SUS at ~60%, REL at ~40%.

   **Filter panel** (lower 40%, #282828 background, 1px #424242 top border):
   - "FILTER" label in 9pt bold secondary
   - Filter type selector: 3 buttons in a row: LP, HP, BP. Each 36x28pt. Selected (LP) has orange background with dark text. Others #383838 with secondary text. 10pt monospaced.
   - 3 knobs in a row: CUTOFF (orange arc, value "7.2k"), RESO (orange arc, value "0.28"), DRIVE (orange arc, value "0.12"). Each 42pt diameter, same label/value treatment as operator knobs.

---

### SCREEN 3: Sensor Modulation View

This is where users see live sensor data, assign sensor-to-parameter mappings, and capture sensor loops.

**Layout:**

1. **Header bar** (48pt, #282828): "SENSOR MODULATION" in 11pt bold green monospaced. Right side: green dot (animated pulse) + "PASSIVE SENSING ACTIVE" in 9pt green monospaced on green at 10% opacity background, rounded rect badge.

2. **Three-column layout:**

   **Left column (26%): Sensor Readouts**
   - "SOURCES" label in 9pt bold secondary, top
   - 11 rows, one per sensor source. Each row 32pt tall:
     - Small activity dot (6pt diameter): lit in sensor color when level > threshold, #383838 when inactive
     - Source name in 9pt monospaced primary text: ACCEL X, ACCEL Y, ACCEL Z, GYRO X, GYRO Y, GYRO Z, CAM MOTION, MIC AMP, MIC LOW, MIC MID, MIC HI
     - Horizontal level bar: 52pt wide, 10pt tall, #383838 background, filled from left with sensor color proportional to current value
     - Numerical value in 8pt secondary monospaced, right-aligned (show values like "0.42", "-0.18", "0.87")
   - Color coding: ACCEL/GYRO rows = green (#2D8B4E), CAM rows = blue (#2E6B9E), MIC rows = orange (#E8913A)
   - Rows separated by 0.5px #424242 dividers

   **Center column (52%): Modulation Matrix**
   - Column headers across top in 8pt secondary monospaced, centered: MOD IDX, CARRIER, FDBK, CUTOFF, RESO, LEVEL
   - Row labels on left matching the 11 sensor sources in 7pt secondary monospaced
   - Grid: 11 rows x 6 columns. Each cell 32pt tall.
     - Inactive cells: #383838 at 30% opacity
     - Active mappings: sensor-colored background at 20% opacity with a filled 12pt rounded square in the center at 90% opacity in the sensor color
     - 4 active mappings to show:
       1. ACCEL X to MOD IDX (green square)
       2. CAM MOTION to CARRIER (blue square)
       3. MIC AMP to CUTOFF (orange square)
       4. MIC HI to LEVEL (orange square)
     - Cell borders: 0.5px #424242 at 30%
   - The active cells should visually pop against the inactive ones. The contrast is critical: this matrix is the centerpiece of the screen.

   **Right column (22%): Capture Panel**
   - "CAPTURE" label in 9pt bold secondary
   - Record button: full-width rounded rect, 48pt tall, 1px #424242 border, #282828 background. Red circle icon (12pt) + "RECORD" in 10pt bold secondary text centered.
   - 1px #424242 divider
   - "LOOPS (2)" label in 8pt secondary
   - 2 loop cards stacked vertically, each in a #282828 rounded rect with 1px #424242 border, 8pt padding:
     - Card 1: "Loop 1" in 9pt medium monospaced primary text. "4.2s" in 8pt secondary right-aligned. Source: "ACCEL X" in 7pt green monospaced. Waveform thumbnail: 30pt tall #383838 rounded rect with a green sine-like waveform drawn inside. Controls: "LOOP" chip (green text, active state) + "ONCE" chip (#808080 text) + trash icon #808080 far right.
     - Card 2: "Loop 2" in 9pt medium monospaced. "2.8s". Source: "MIC AMP" in 7pt orange. Orange waveform in thumbnail. Controls: "LOOP" chip (inactive), "ONCE" chip (orange, active) + trash icon.

---

### Navigation

Bottom tab bar, consistent across ALL three screens:
- 3 tabs: PERFORM (piano keys icon), FM ENGINE (waveform circle icon), SENSORS (sensor/radio wave icon)
- #282828 background, 1px #424242 divider on top
- Selected tab: orange icon + orange 9pt medium monospaced label
- Unselected: #808080 icon + #808080 label
- Icons 20pt, labels 9pt
- Tab bar height: 52pt total, vertically centered content
- IMPORTANT: Performance View includes this tab bar but it could be hidden during active performance via a swipe-down gesture. Show it visible in the mockup.

---

### Key Design Notes
- This is a PROFESSIONAL music performance app. It should look like it belongs alongside Moog Model 15, Animoog, or Korg Gadget on the App Store. Dense, precise, technical.
- No gradients, no shadows, no blur effects. Flat, functional surfaces.
- The color system is strict: orange = primary interactive, blue = secondary/envelope/operator B, green = sensor/environmental, red = recording/error only.
- Every numerical value must be visible at all times. No hover states, no hidden info. This is an iPad touch instrument.
- Landscape orientation only for these mockups.
- The Performance View is the hero screen. It should feel like picking up an instrument, not opening an app.
- The sequencer overlay (Screen 1B) is a SEPARATE frame/page showing the same screen in a different mode state. Generate it as a second artboard or variant of Screen 1.
