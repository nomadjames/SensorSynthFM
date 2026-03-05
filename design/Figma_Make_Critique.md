# SensorSynth FM -- Figma Make Design Critique

**Date:** March 4, 2026
**Reviewer:** Claude (Cowork)
**Source:** Figma Make output from `Figma_Make_Prompt.md`
**File:** FM Synth (Y2N52QFPhdQnytZi3PPH4L)

---

## Overall First Impression

Figma Make produced all three screens, and the general mood is right: dark, dense, professional. It reads as a serious music app, not a toy. The color system came through reasonably well (orange primary, blue secondary, green for sensors). The bottom tab bar is consistent across all three screens, which is good structural continuity.

That said, the output is a starting point, not a finished design. There are meaningful gaps between what was prompted and what was generated, and several areas where the layout decisions need rethinking before this could serve as a credible design artifact for either development or your UX program deliverables.

---

## Screen 1: Performance View

### What Works

- **Layout split is correct.** The XY performance surface takes roughly 60% of the width, sequencer panel takes the right 40%. This matches the spec and gives the playing surface the dominance it needs.
- **Transport strip is lean.** Play button, BPM "124", patch name "Passive Field 01" are all present and correctly positioned at the top. The strip stays thin and does not compete with the playing area.
- **Touch point rendering.** Three mock touch points are visible on the XY surface with distinct colors (orange, green, blue). The numbered dots at different positions communicate the multi-touch MPE concept effectively.
- **Sequencer track selector.** T1 through T4 are present, with T1 highlighted in orange. The step grid below shows colored cells (blue for active steps, orange for playback position). This is structurally correct.
- **Macro knob strip at bottom.** Six arc knobs are visible along the bottom. The layout gives them enough horizontal space.
- **Tab bar.** PERFORM, FM ENGINE, SENSORS tabs at the bottom with icons. PERFORM is highlighted orange.

### Issues and Gaps

1. **XY surface grid lines are too prominent.** The spec called for very subtle grid lines (#424242 at 25% opacity for regular lines, 70% for octave markers). What Figma Make produced has grid lines that are visible enough to read as structural, which is fine, but they lack the differentiation between regular pitch intervals and octave boundaries. Every 12th horizontal line should be noticeably brighter. This visual cue is how a performer intuits pitch range at a glance.

2. **Missing axis labels.** The spec called for "TIME" arrow label at bottom-right and "PITCH" arrow label (rotated 90 degrees) on the left side of the XY surface. These are absent. For a first-time user (and for your UX evaluation), these labels orient the performer to the hybrid X/Y mapping concept. Without them, the surface looks like a generic pad.

3. **Missing MPE badge.** The spec called for an "MPE" badge in the top-right corner of the XY surface (orange text on orange/12% opacity background). This is missing. MPE is a key differentiator of the instrument and should be communicated on-screen.

4. **Pressure rings not rendering.** The three touch points show as small dots, but the spec called for larger pressure-indicating rings around each dot (30-50pt diameter, varying sizes). The pressure visualization is central to the MPE interaction model. Without the outer rings, there is no visual communication that pressure/force is being sensed.

5. **Sequencer step grid is too small.** Only one row of 16 steps is clearly visible for the selected track. The spec called for 4 rows (one per track) of 16 step cells, all visible simultaneously. This matters because parameter locks and cross-track relationships are key to the Digitone-inspired workflow. A performer needs to see all four tracks at once.

6. **Parameter locks row missing or too subtle.** The spec called for a "PARAM LOCKS" label with chip buttons (NOTE, VEL, MOD, FILT) below the step grid. These appear to be present but are very small and low-contrast. They need to be more legible because parameter locks are one of the most powerful features of the sequencer.

7. **Sensor activity indicators in transport strip.** The spec called for 4 small vertical bars (ACC, GYR, CAM, MIC) filled from bottom with sensor-appropriate colors, plus 7pt labels beneath. These are either missing or too small to see at this zoom level. They are the only place on the Performance View where the user gets feedback about sensor activity, so they are important for the passive sensing concept.

8. **Macro knob labels are barely legible.** The 7pt labels above each knob (CUTOFF, RESO, MOD, FDBK, REVERB, SENS) appear present but are very faint. In a live performance context, these need to be readable without squinting. Consider bumping to 8-9pt.

9. **Missing RND (randomize) button.** The spec included a randomize button with dice icon after the 6 macro knobs, separated by a vertical divider. This is absent. Randomization with constraints is a design feature that supports creative exploration.

---

## Screen 2: FM Engine View

### What Works

- **Algorithm diagram is present and structurally correct.** Four operator nodes (A1, A2, B1, B2) are arranged in a 2x2 grid with the correct color coding (orange for A group, blue for B group). Routing lines between operators are visible, and green "OUT" lines from carriers are shown.
- **Algorithm selector.** Buttons 1-8 are present in a row below the diagram, with one highlighted in orange (appears to be #4). Left/right chevrons on each end. This matches the spec.
- **Operator picker row.** A1, A2, B1, B2 selector beneath the algorithm diagram, with A1 highlighted. Color indicators present.
- **Operator detail panel.** Right side shows "OPERATOR A1" header with a set of parameter knobs. The layout gives this the larger share of screen width, which is appropriate since this is where users spend most of their editing time.
- **ADSR visual.** Blue vertical bars for the envelope stages are visible in the right panel. The compact bar-chart approach is correct per the spec.
- **Filter section.** Bottom-right shows LP/HP/BP selector with LP highlighted in orange, plus CUTOFF, RESO, DRIVE knobs. Structurally correct.
- **Waveform selector.** "SIN" chip is visible near the operator header.
- **Header bar.** "FM ENGINE" in orange with patch name. Correct.

### Issues and Gaps

1. **Knob count in operator detail.** The spec called for 7 knobs: RATIO, LEVEL, FDBK, ATK, DEC, SUS, REL. From the screenshot, it is difficult to confirm all 7 are present and labeled. The first 3 should use orange arcs and the last 4 (envelope) should use blue arcs. Verify that the color distinction is applied, as it communicates the conceptual grouping (synthesis parameters vs. envelope parameters).

2. **Algorithm diagram connection lines need clarity.** The routing lines between operators are thin and subtle. For algorithm 3 (or whichever is selected), the modulation paths need to be immediately readable. Consider slightly thicker lines or a subtle glow/highlight on active connections. The algorithm diagram is described in the design guidelines as "the visual anchor" of this screen, and at the current rendering, the connections could be missed.

3. **Operator node sizing.** The spec called for 44x28pt rounded rectangles. The nodes look appropriately sized, but confirm the touch target is at least 44pt for tapping to select an operator. This is a frequent interaction.

4. **Missing "3 of 8" indicator.** The spec called for a right-aligned "3 of 8" (or appropriate number) in 9pt orange next to the ALGORITHM label, telling the user which algorithm out of 8 is currently selected. This contextual indicator may be present but is not clearly visible.

5. **ADSR bar proportions.** The spec called for 26x52pt bars. The bars in the screenshot look potentially shorter than specified. The bars need enough height that the proportional fill is readable (the difference between an attack of 0.02 and 0.30 should be visually obvious).

6. **Knob values.** The spec provided specific realistic values: Ratio "2.60", Level "80", Fdbk "2", Atk "0.02", Dec "0.30", Sus "0.60", Rel "0.40". Verify these are rendered inside or below each knob in 7pt secondary text. Values should always be visible per the design guidelines ("numerical values always visible, no hover to reveal on iPad").

---

## Screen 3: Sensor Modulation View

### What Works

- **Three-column layout is implemented.** Left column shows sensor readouts, center shows the modulation matrix, right shows the capture panel. This is the correct structural approach from the spec.
- **Sensor source list is complete.** All 11 rows are present: ACCEL X/Y/Z, GYRO X/Y/Z, CAM MOTION, MIC AMP, MIC LOW, MIC MID, MIC HI. Each has a colored activity dot and a horizontal level bar. Color coding appears correct (green for accelerometer/gyro, blue for camera, orange for mic).
- **Modulation matrix.** Column headers are visible across the top (MOD IDX, CARRIER, TIME, CUTOFF, RESO, LEVEL -- note: "TIME" differs from spec which said "FDBK"). Row labels on the left match sensor sources. Active mappings show as colored cells.
- **Capture panel.** RECORD button with red dot is present. Two loop cards are shown below with waveform thumbnails. LOOP/ONCE toggle buttons visible. This matches the spec structure.
- **Header bar.** "SENSOR MODULATION" in green. The right-side badge for "PASSIVE SENSING ACTIVE" appears to be present.

### Issues and Gaps

1. **Matrix column header mismatch.** The spec called for: MOD IDX, CARRIER, FDBK, CUTOFF, RESO, LEVEL. The rendered matrix appears to show TIME instead of FDBK. "FDBK" (feedback) is an FM synthesis parameter that is important as a modulation destination. "TIME" is ambiguous in this context. This should be corrected.

2. **Matrix active mapping count.** The spec called for 4 active mappings: ACCEL X to MOD IDX, CAM MOTION to CARRIER, MIC AMP to CUTOFF, MIC HI to LEVEL. Verify that exactly these mappings are shown, as they were chosen to demonstrate the concept of different sensor types controlling different synthesis parameters. The green cell in the ACCEL X row looks correct. The blue cell in the CAM MOTION row looks correct. Check the mic mappings.

3. **Matrix density and readability.** The matrix is the centerpiece of this screen per the design guidelines. At the current rendering, the inactive cells may be too visually prominent relative to the active ones. The spec called for inactive cells at #383838/40% opacity and active cells with sensor-colored background at 25% opacity plus a 90% opacity filled square. The contrast ratio between active and inactive needs to be strong enough that the 4 active mappings "pop" immediately.

4. **Sensor level bars seem narrow.** The spec called for 48pt wide, 10pt tall bars. Some of the bars in the left column look potentially narrower. These should be wide enough that the fill level is readable at a glance. The whole point is that the user sees "this sensor is currently providing this much signal" in real time.

5. **Loop card waveform thumbnails.** The spec called for a 28pt tall #383838 rounded rect with a colored waveform drawn inside. The waveform rendering in the two loop cards looks plausible, but confirm the color coding: Loop 1 should show a different color than Loop 2 if they are capturing different sensor sources. The spec example had "ACCEL X" as the source label in blue.

6. **Capture panel LOOPS label.** Should read "LOOPS (2)" in 8pt secondary to indicate count. Verify this is rendered.

7. **Lower half of screen is empty.** Both the left sensor column and the center matrix leave a large amount of dark space in the lower half. This is partly expected since the sensor list and matrix are compact. However, it raises the question of whether this space could be used more productively. Possible additions for a future iteration: a small live waveform/oscilloscope preview of the selected sensor source, or expanded loop editing controls.

---

## Cross-Screen Consistency

### Tab Bar
The bottom tab bar appears consistent across all three screens: three tabs (PERFORM, FM ENGINE, SENSORS) with icons, orange highlight on the active tab. This is correct and provides reliable navigation.

### Header Bars
Each screen has a 48pt header bar with the screen name in the appropriate accent color (orange for FM ENGINE, green for SENSOR MODULATION). The Performance View header is the transport strip, which integrates differently but still occupies the top position. This is consistent enough.

### Color System Adherence
The strict color rules (orange = primary/interactive, blue = secondary/envelope, green = sensor) appear to be followed across all three screens. The blue cells in the sequencer correctly represent active steps. The green sensor bars in the Sensor view are correct. The orange algorithm selector and filter type buttons are correct. This is one of the strongest aspects of the Figma Make output -- the color language reads as intentional and systematic.

### Typography
Hard to fully evaluate at screenshot resolution, but the monospaced treatment appears applied to numerical values and labels. Check at 100% zoom that the font sizes match the spec (7-9pt for labels, 14-16pt for large values).

---

## Recommendations for Next Steps

### Priority 1: Fixes (before using for UX deliverables)

- Add MPE badge and axis labels to Performance View XY surface
- Correct the matrix column header (FDBK not TIME)
- Add pressure rings to the XY touch points
- Ensure all 4 sequencer track rows are visible
- Add the RND (randomize) button to the macro strip

### Priority 2: Refinements

- Differentiate octave grid lines from regular pitch lines on XY surface
- Increase active mapping contrast in the modulation matrix
- Verify all knob values are rendered with realistic data
- Verify ADSR bar heights are proportional and readable
- Add sensor activity indicators to the Performance View transport strip

### Priority 3: Considerations for UX Program

- The three-screen structure maps well to a task analysis: perform, design sound, assign modulation. This clean separation supports your UX evaluation framework.
- The empty space in the Sensor Modulation View could be a strength if you frame it as "room for progressive disclosure" or future features. Alternatively, it could be a critique point if the information density feels unbalanced compared to the other two screens.
- The modulation matrix is the most novel UI element (no direct precedent in existing iPad synths). It deserves extra attention in usability evaluation: can users understand source-to-destination mapping from the visual alone?
- The XY performance surface design philosophy (continuous pitch vs. discrete keys) is a significant design decision worth exploring in your research. The current rendering communicates it, but axis labels and pressure visualization are needed to make the concept self-documenting.

---

## Summary Assessment

| Aspect | Rating | Notes |
|--------|--------|-------|
| Layout fidelity to spec | 7/10 | Structure is correct, details need polish |
| Color system compliance | 8/10 | Strongest aspect, color language is consistent |
| Typography | 6/10 | Hard to verify at screenshot scale, needs 100% check |
| Information completeness | 6/10 | Missing several specified elements (MPE badge, axis labels, RND button, etc.) |
| Touch target sizing | 7/10 | Appears reasonable but needs measurement in Figma |
| Cross-screen consistency | 8/10 | Tab bar and header patterns are solid |
| Professional appearance | 8/10 | Reads as a credible music app, not a prototype toy |
| UX program readiness | 5/10 | Needs Priority 1 fixes before using as a design artifact |

The 10-point scale here is relative to "ready to present as a design mockup in a UX program context." The ratings are not grades; they are meant to indicate where effort should be focused. The structural foundation is solid. The details need a manual pass in Figma to bring it up to the standard your design guidelines describe.
