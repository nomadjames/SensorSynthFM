# SensorSynth FM -- Action Plan
**March 4, 2026 -- Pick up where you left off**

---

## Where We Are

You have three Figma Make screens (Performance View, FM Engine, Sensor Modulation) in the FM Synth file. The structural foundation is solid but needs revision. During our last conversation you proposed four design changes to the Performance View that fundamentally rethink how it works. Those changes ripple into all three screens.

The updated Figma Make prompt (v2) is ready in `Figma_Make_Prompt_v2.md`. You can paste it into Figma Make to regenerate the Performance View.

---

## What Changed (Your Four Ideas)

1. **Full-screen touch surface** -- XY pad fills nearly the entire screen instead of a 60/40 split with the sequencer.
2. **Sequencer as overlay** -- Hard toggle between performance mode and sequence mode. The sequencer appears ON TOP of the touch surface when active, disappears when performing.
3. **Controls on the rim** -- Transport, macros, and mode toggles live along the edges of the screen. Ergonomically optimized for thumbs in landscape grip.
4. **Left/right hand switchable** -- Entire rim layout mirrors for left-handed users. Needs to be designed with mirroring in mind from the start.

---

## Action Items (in order)

### Step 1: Regenerate Performance View in Figma Make
- Open `Figma_Make_Prompt_v2.md`
- Paste the Performance View section into Figma Make
- Generate and compare against v1

### Step 2: Manual Fixes in Figma (all screens)

**Performance View (new layout):**
- [ ] Verify the XY surface fills at least 85% of screen area
- [ ] Confirm rim controls are within thumb-reach zones (outer 80-100pt sides, bottom 60pt)
- [ ] Check that the sequencer overlay has clear visual separation from the touch surface (darker overlay background, distinct border)
- [ ] Verify the mode toggle (PERFORM / SEQUENCE) is prominent and obvious
- [ ] Add the MPE badge to XY surface corner
- [ ] Add pitch/time axis indicators (subtle, do not clutter)
- [ ] Add pressure rings around touch points (not just dots)
- [ ] Verify sensor pulse bar is visible along one edge

**FM Engine View (from v1 critique):**
- [ ] Verify all 7 operator knobs are present and labeled (RATIO, LEVEL, FDBK, ATK, DEC, SUS, REL)
- [ ] Confirm orange arcs on synthesis knobs, blue arcs on envelope knobs
- [ ] Check algorithm connection lines are thick enough to read at a glance
- [ ] Verify "3 of 8" indicator next to ALGORITHM label
- [ ] Confirm ADSR bars are tall enough to show proportional differences
- [ ] All knob values must be visible (no hidden data)

**Sensor Modulation View (from v1 critique):**
- [ ] Fix column header: FDBK, not TIME
- [ ] Increase contrast between active and inactive matrix cells
- [ ] Verify the 4 active mappings match spec (ACCEL X > MOD IDX, CAM MOTION > CARRIER, MIC AMP > CUTOFF, MIC HI > LEVEL)
- [ ] Check sensor level bars are wide enough to read (48pt spec)
- [ ] Verify loop card waveform colors distinguish between loops

### Step 3: Cross-Screen Consistency Pass
- [ ] Tab bar identical across all three screens
- [ ] Header bar height and typography consistent
- [ ] Color system strictly followed (orange/blue/green/red rules)
- [ ] All interactive elements meet 44pt minimum touch target
- [ ] Monospaced font on all numerical values

### Step 4: Evaluate for UX Program Use
- [ ] Can someone unfamiliar with the app understand each screen's purpose in 5 seconds?
- [ ] Is the modulation matrix self-explanatory? (This is the most novel UI element and the one most likely to confuse first-time users)
- [ ] Does the full-screen performance surface communicate "this is the instrument" immediately?
- [ ] Is the mode toggle (perform vs. sequence) discoverable without instruction?
- [ ] Can you articulate the design rationale for the rim layout in a presentation? (Ergonomic thumb zones, landscape grip, left/right mirroring)

---

## Open Design Questions to Decide

These came up during critique. You do not need to answer them now, but they will need answers eventually:

1. **Macro knobs placement:** Fixed on the rim (always visible, takes space) or pull-up drawer from bottom edge (hidden until needed, more space for performance)? Recommendation: try the drawer approach first. It gives more performance area and the macros are secondary to the XY surface during actual playing.

2. **Sequencer overlay opacity:** Semi-transparent (performer sees touch surface beneath) or fully opaque (cleaner, no visual clutter)? Recommendation: start with opaque. Transparent overlays create gesture disambiguation problems that are hard to solve.

3. **Sensor feedback in Performance View:** The thin color pulse bar along one edge is the current proposal. Alternatives: small sensor dots in a corner, or animated border glow. The pulse bar is the least intrusive while still communicating "sensors are active."

4. **Left/right switch mechanism:** Settings toggle (change once, stays)? Or auto-detect based on grip pattern? Recommendation: settings toggle. Auto-detection sounds clever but will frustrate users who grip the iPad differently from what the algorithm expects.

5. **Empty space on Sensor Modulation View:** The lower half of the screen is underused. Options: live oscilloscope of selected sensor, expanded loop editing, or leave it as intentional breathing room. For UX evaluation purposes, "intentional negative space" is a defensible design choice if you can articulate why.

---

## Files Reference

| File | Purpose |
|------|---------|
| `Figma_Make_Prompt.md` | Original prompt (v1), produced current Figma screens |
| `Figma_Make_Prompt_v2.md` | Updated prompt with full-screen performance view (use this next) |
| `Figma_Make_Critique.md` | Detailed critique of v1 output, screen by screen |
| `Action_Plan_March4.md` | This file |
| `design_guidelines.md` | Color system, typography, component patterns (source of truth) |
| `fm_engine.md` | FM synthesis architecture spec |
| `sensor_mapping.md` | Sensor sources and modulation targets |
| `masterplan.md` | Product vision and design philosophy |

---

## Git Status

You have uncommitted local changes to CLAUDE.md, tasks.md, and workflow.md. Nothing urgent, but worth committing next time you are in a coding session so the repo stays current.
