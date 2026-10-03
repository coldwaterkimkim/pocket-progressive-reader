# Pocket Progressive Reader / Attention-Scaffolded Reading
## Codex Handoff

### 0. Purpose

This file restores the current project context inside Codex. Do not restart ideation from zero.

Before changing code, inspect these sibling files:
- `pocket_progressive_reader_hardware_lab_v4.html`
- `chatgpt_progressive_reader_v2.3.2.user.js`

The userscript is a reference for the original chunking/reveal logic. The v4 HTML is the current hardware + UX simulator.

---

# 1. Project in one sentence

Build and validate a tiny, portable reading interface that **reduces unnecessary attentional choice during reading** by controlling what text is available to attention at each moment, while preserving enough reader agency for regression and context recovery.

This started as a tiny hardware reader concept, but the deeper thesis is broader:

> The product may not primarily reduce the semantic difficulty of understanding text. Its value may come from reducing **attentional routing overhead**: the repeated low-level selection of “what should I look at / process now?”

Useful internal phrases:
- attention-scaffolded reading
- attentional friction
- attention routing overhead
- fixed-gaze progressive reading
- temporal disclosure interface
- reduce attentional degrees of freedom

Do not present these as established scientific terms unless verified. They are product/design framings.

---

# 2. Origin

The user already built a ChatGPT-specific Progressive Reader userscript.

Core behavior of the current userscript:
- sentence segmentation
- Korean-oriented chunking
- target chunk size: 4 eojeol
- minimum: 3 eojeol
- maximum: 5 eojeol
- punctuation-aware chunk-boundary scoring
- right arrow: next chunk
- left arrow: previous chunk
- progressive reveal
- existing ChatGPT DOM remains the document context

Relevant code is in `chatgpt_progressive_reader_v2.3.2.user.js`.

The dedicated reader should not blindly port DOM-specific code. Reuse/adapt only the reading-engine ideas.

---

# 3. Conceptual evolution

## Early framing
- tiny e-reader
- page replaced with sentence/chunk-level reading
- portable
- battery-powered
- USB required
- wireless desirable later
- physical controls only
- click-wheel / iPod-like interaction desirable

## Current framing
The stronger hypothesis is:

> Reading interfaces expose too many simultaneous candidates for attention. A constrained interface can externalize part of attentional selection so the user spends less effort deciding what to process now.

The key design target is **not simply reducing eye movement**.

Preserve these distinctions:
- do not eliminate useful regression
- do not force speed reading
- do not remove reader agency
- reduce unnecessary attentional choice
- make the current target spatially stable
- hide future content when it creates attentional leakage
- optionally retain past context for recovery

---

# 4. Observation that drove the current design

The user noticed:
- videos with subtitles feel substantially easier to focus on / become immersed in than the same video without subtitles
- possible explanation: subtitles provide a predictable attentional anchor / trajectory

In the reader simulator:
- when future text was shown below the current focus, the user's eyes were repeatedly pulled toward that future content
- when the current focus itself moved vertically, that was also undesirable

Therefore the product currently needs:
1. fixed spatial focus
2. no future-content leakage
3. optionally visible past context
4. explicit user-controlled progression

---

# 5. Current presentation modes

As of v4, keep only these 3 modes.

All three use the **same bottom-fixed current reveal position** so comparisons are not confounded by gaze-anchor position.

## A. Current Only
Only the current reveal unit is visible.

```text


CURRENT
────────
```

Properties:
- zero future leakage
- zero past context
- strongest attentional constraint
- useful as a control condition

## B. Past-only Typewriter
The current reveal unit is fixed at the bottom. Previously revealed units appear above it. No future text appears.

```text
past -3      very faint
past -2      faint
past -1      grey

CURRENT      full contrast
────────
```

When advancing:
- no scroll animation is required
- redraw instantly
- the new current unit stays in exactly the same location
- old current becomes past context above

“Typewriter” here describes the history-stack / stream logic, not literal smooth scrolling.

## C. Sentence-bounded Typewriter
Same bottom-fixed current unit. Past context is retained only within the current sentence.

When the next sentence begins:
- clear the history stack
- show only that sentence's first reveal unit at the same fixed bottom focus position

This creates a sentence-level semantic reset without moving the gaze anchor.

---

# 6. Future-content policy

Current conclusion:
- future text should not be readable
- prior experiments with grey future text pulled attention downward

Removed/deprioritized modes:
- grey future
- blurred future
- masked future
- focus slit
- old replace mode
- old center-fixed typewriter variants

Do not reintroduce these unless explicitly requested for a new experiment.

---

# 7. Reveal-unit concept

A reveal unit is **not necessarily a sentence**.

Sentence-level reveal was rejected as the default because sentence lengths vary too much.

Preferred conceptual definition:

> A reveal unit is a text segment that fits on a single visual line and is reasonably similar in rendered visual width to neighboring reveal units, while preserving natural linguistic boundaries when possible.

Sentence boundaries are useful as constraints / metadata, not necessarily reveal units.

Current segmentation modes for experimentation:

1. `Visual balanced`
   - preferred default
   - use rendered pixel width
   - attempt similar-width reveal units
   - prefer punctuation / natural boundaries
   - each reveal unit must fit on one line

2. `Visual greedy`
   - fill line until next word would overflow

3. `3–5 eojeol baseline`
   - reference condition derived from the original userscript

The user wants to compare them rather than prematurely selecting one.

---

# 8. Hardware concept

Ultimate form:
- very small portable reader
- physical controls only
- no touchscreen
- rechargeable battery
- USB-C required
- wireless may be added later
- standalone after content transfer
- device-side reading/chunking logic is preferred
- file-format normalization may remain host-side if EPUB/PDF parsing becomes wasteful on MCU

Product should not exceed roughly the iPod Classic front-envelope unless later evidence justifies relaxing it.

Reference envelope:
- iPod Classic: ~61.8 mm × 103.5 mm × 10.5 mm

Desired iPod-like interaction:
- up
- down
- left
- right
- rotary wheel
- physical feel matters eventually

Software mapping concept:
- left/right: reveal-level navigation
- up/down: larger semantic navigation such as sentence
- wheel: one reveal unit per detent / scrub
- no acceleration for MVP

---

# 9. Current hardware architecture direction

## MCU
Preferred modular MVP: `Seeed XIAO ESP32-S3 Plus`

Why:
- tiny footprint
- more flash / GPIO than regular XIAO S3
- PSRAM
- USB-C
- Wi-Fi/BLE already available
- LiPo support
- expansion headroom

## Navigation
Preferred MVP path: `ANO directional navigation + rotary encoder + I²C adapter`

Why:
- physical 5-way + wheel
- I²C avoids spending ~7 GPIO on the direct breakout
- easier prototype wiring

Direct breakout may become attractive on a custom PCB later.

## Battery
LiPo. 500 mAh and 1200 mAh reference batteries were included in the simulator. Capacity is **not finalized**.

## Connectivity
MVP: USB-C required.
Later: BLE / Wi-Fi possible.
Do not let wireless inflate MVP scope without a reason.

---

# 10. Display research and current candidates

Important principle:

**Panel active area, panel outline, breakout/module footprint, interface, resolution, and aspect ratio are separate variables.**

Most relevant current candidates:

## A. 1.9" 320×170
Approx:
- active: 42.72 × 22.70 mm
- aspect: ~1.88:1
- SPI/ST7789 family
- easy electronics
- safe baseline

## B. 2.19" 400×240
Approx:
- active: 52.80 × 31.68 mm
- outline: ~59.81 × 34.82 mm
- wider but less bar-like
- potentially useful if more past context matters

## C. 2.23" 480×200 ultra-wide
Approx:
- active: 52.42 × 21.72 mm
- outline: ~57.79 × 23.92 mm
- aspect: ~2.41:1
- geometry attractive
- interface more complex: MIPI/RGB rather than easy SPI
- pushes toward custom-PCB / parallel-interface complexity

## D. 2.25" 284×76 ultra-wide SPI
Approx:
- active: ~55.29 × 14.80 mm
- outline: ~62.50 × 17.90 mm
- aspect: ~3.74:1
- ST7789P3
- 4-wire SPI
- especially attractive for one-line / bottom-focus reading
- BUT outline is ~0.7 mm wider than the 61.8 mm iPod-width target

This is a major candidate if the width constraint can relax slightly.

## E. 2.4" 310×100 bar
Approx:
- active: ~55.80 × 18.00 mm
- outline: ~63.60 × 21.10 mm
- aspect: ~3.10:1
- ST7789 / SPI-friendly
- exceeds 61.8 mm width target by ~1.8 mm

## F. 2.0" 320×240
Approx:
- active: 40.80 × 30.60 mm
- conventional control condition
- useful for comparison, less aligned with the emerging ultra-wide concept

Important:
- verify exact specs and availability again before purchase
- some ultra-wide panels are raw LCM/FPC parts, not plug-and-play modules

---

# 11. Display-selection hypothesis

The critical hardware question is no longer just “what diagonal size?”

It is:

> How much horizontal reading lane and how many lines of past context does the preferred presentation actually need?

Potential mapping:
- if 0–1 past lines are enough: extremely shallow ultra-wide displays become attractive, e.g. 2.25" 284×76
- if 2–4 past lines matter: somewhat taller ultra-wide displays may be better, e.g. 2.23" 480×200 or 2.19" 400×240

This is why the simulator exposes a `Past capacity` metric.

---

# 12. Current software artifact

Current file: `pocket_progressive_reader_hardware_lab_v4.html`

Purpose:
- not production UI
- experimental lab for hardware + interaction decisions

It contains:
- reveal segmentation controls
- Current Only
- Past-only Typewriter
- Sentence-bounded Typewriter
- bottom-fixed focus
- real display presets
- active area / module geometry
- iPod envelope comparison
- past-context capacity
- physical-size calibration using a credit card
- fit view vs actual-size view
- hardware compatibility warnings

Treat it as an experiment harness.

---

# 13. Important next-step realization: phone prototype before hardware

Before ordering hardware, the user realized the interaction can be tested more realistically on an iPhone. This is now a preferred intermediate step.

Proposed sequence:

```text
Desktop HTML lab
→ mobile prototype / PWA
→ actual reading sessions on phone
→ determine reveal width, font size, past-context requirement
→ freeze display geometry
→ order ESP32 + display + wheel
→ physical prototype
→ custom PCB only after interaction is validated
```

Why phone first:
- real handheld reading distance
- one-handed use
- real reading sessions
- cheap iteration
- can emulate multiple physical display active areas
- avoids premature hardware orders

A mobile-first PWA is likely enough initially. Do not jump to native SwiftUI unless native capability becomes necessary.

---

# 14. What can be tested on phone

Good phone/PWA validation targets:
- Current Only vs Past-only vs Sentence-bounded
- fixed bottom focus
- reveal width
- font size
- line spacing
- past-context line count
- backtracking frequency
- sustained attention
- reading speed
- subjective effort
- comprehension
- hand-held viewing distance
- simulated panel geometry

Not faithfully testable on phone:
- physical button force
- rotary detents
- wheel feel
- final grip
- final device weight
- actual TFT optical characteristics
- battery life
- final enclosure thickness

---

# 15. Suggested experiment design

Do not optimize only for “feels focused.”

Compare at least:
A. Normal full-page reading
B. Current Only
C. Past-only Typewriter
D. Sentence-bounded Typewriter

Measure:
- reading time
- backtracking count
- voluntary regression count
- concentration rating
- mental effort rating
- comprehension questions
- subjective desire to look ahead
- subjective gaze stability

Key product hypothesis:

> Reducing unnecessary attentional degrees of freedom may improve sustained attention without sacrificing comprehension, provided regression remains available.

This is a hypothesis, not a proven conclusion.

---

# 16. Design principles to preserve

1. Current attention target must be spatially stable.
2. Future content should not compete for attention.
3. Reader agency / regression must remain available.
4. Do not equate fewer eye movements with better reading.
5. Do not accidentally recreate speed-reading RSVP/Spritz as the goal.
6. Hardware should serve the interaction, not dictate it prematurely.
7. Keep MVP small.
8. Test software variables before hard-to-reverse hardware purchases.
9. Avoid animations unless they demonstrably improve reading. Instant redraw is preferred.
10. Use actual rendered width, not only word count, when evaluating reveal size.

---

# 17. Open questions

## Interaction
- Which of the three presentation modes is best?
- How many past lines are useful?
- Is bottom focus truly best over long sessions?
- Is Visual Balanced better than simpler greedy chunking in practice?
- How frequently does the user want to regress?
- Does fixed-focus reading help comprehension, or only subjective concentration?

## Display
- Is ~55 mm active horizontal width enough?
- Is ~15 mm active height too shallow?
- Is 2.23" 480×200 worth interface complexity?
- Should the strict 61.8 mm body-width constraint relax by ~1–2 mm to unlock better SPI bar panels?

## Hardware
- exact battery capacity
- final display part
- raw panel vs dev module
- need for microSD
- BLE/Wi-Fi scope
- custom PCB timing
- wheel mechanical implementation

## Product framing
- Is this primarily a reader?
- Or a broader attention-interface pattern whose first testbed is reading?

Do not resolve these by intuition alone. Design experiments.

---

# 18. Recommended immediate Codex task

Build a **mobile-first iPhone PWA behavioral prototype** based on the current experiment.

Goals:
- run on iPhone Safari
- installable to Home Screen / PWA where feasible
- offline after initial load
- import/paste text
- bottom-fixed Current Only / Past-only / Sentence-bounded modes
- Visual Balanced / Greedy / Eojeol segmentation
- simulate actual panel active areas
- large lower-screen touch controls that emulate physical left/right/up/down/wheel semantics
- use platform haptics only if actually supported; do not fake unsupported APIs
- save reading state locally
- optional experiment/logging panel
- minimal UI during reading

Before implementation:
1. inspect v4 HTML
2. inspect original userscript
3. state what logic will be reused vs rewritten
4. propose the mobile interaction model
5. identify iOS Safari / PWA constraints
6. only then modify/create files

Do not blindly shrink the desktop lab onto a phone. The mobile app should be a **behavioral prototype**, not a compressed dashboard.

---

# 19. How to work with the user

Treat the user as:
- product owner
- technically literate about frontend flow, APIs, JSON, Git, tests, builds
- not a traditional backend/infrastructure engineer
- comfortable using Codex as a development collaborator
- wants critical evaluation, not automatic agreement
- values fast validation but will accept complexity when expected value is high

When reporting implementation work:
1. explain what changed in the product
2. cause / reasoning
3. how it works
4. what validation means
5. remaining risks and decisions

For code/specs, prioritize technical precision.

---

# 20. Instruction to Codex

Do not restart discovery from zero.

Use this document as current project state, but verify code-level facts by reading the actual files.

If code and this handoff conflict:
- code is authoritative for current implementation behavior
- this handoff is authoritative for product intent and decisions
- call out meaningful conflicts instead of silently choosing

Do not add features merely because they are possible. Keep experiments separable so we can identify which variable causes an effect.
