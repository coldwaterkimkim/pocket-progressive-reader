# Context Margin and rotary response — 2026-10-08

Owner requests symmetric scrolloff under Text & Spacing, responsive CW/CCW focus, and breathing room around yellow/black highlights.

## Reading layout

`scrollMarginLines` is 0/1/2. New settings default to 1. Saved settings without this field decode to 0, preserving the prior reading experience and source/position. Sample UI tests use explicit zero until a test chooses a margin.

- Zero preserves Current Only and accumulated-past behavior, including the old no-future rule.
- Positive values show real neighboring content above and below in vertical chunk views. This intentionally supersedes no-future/strict Current Only only while a margin is enabled. Rows share normal ink/opacity.
- The native window uses existing history preference where possible, with enough rows for both margins + an active line, bounded by actual panel capacity and document length. Effective margin is capped at floor((rows - 1) / 2). One active line always remains.
- The active cursor and visible window stay separate. Forward/backward chunk, sentence and word navigation shift the window only after crossing its symmetric safe bounds. At document edges missing context is allowed; no placeholder/duplicate lines are created.
- Font, line spacing, panel/padding and margin changes recalculate the safe window. Full uses nearby actual DOM visual rows, including Markdown block spacing/headings, and reduces the margin until focus + neighbors fit the viewport. It does not change source structure or typography.
- Horizontal Rail bypasses vertical margin logic. Its horizontal snap and vertical center remain unchanged; its margin picker is disabled.

## Input/render fixes

Native input discarded the angle from gesture start to the first drag event. It also retained signed partial-detent residual across reversals, so CW residue cancelled CCW movement. RotaryStepper counts the initial angle and clears opposing residual while keeping the 15-degree detent. Radius exits and gesture end reset it. Pure tests cover initial movement, reversal and angle wrap.

Full/rail previously serialized the complete document on each focus update and queued one asynchronous WebKit request per index. Now only document/layout changes serialize the source. A single visual request is in flight; completion renders the latest Store cursor. Every input detent still updates Store synchronously. There is no deliberate focus delay; the 250ms persistence debounce remains unrelated to display. WebKit backlog was a structural risk, not a measured latency claim.

Yellow/black token backgrounds expand horizontally by 3 rendering pixels without changing glyph advances, text positions, segmentation or scroll geometry. Text color clipping remains limited to the selected token. Rich rendering uses paint-only shadows; Canvas/CoreText expand the background rectangle.

No timed progression, new opacity rule, unrelated home redesign or hardware change.
