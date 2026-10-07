# Manual word focus — 2026-10-07

This revision follows hands-on owner feedback: fixed-gaze alignment did not provide meaningful benefit and is retired. It supersedes the earlier gaze experiment in READING_REVISION.md; input normalization, three presentation modes, panel geometry and the silver native home remain.

## Reader behavior

All reveals are left-aligned and width-balanced using rendered metrics. Current Only is vertically centered. Both Typewriter modes retain the same bottom position, with continuous past or sentence-local past respectively. Future reveal units remain absent.

Buttons are coarse navigation: left/right reveals and up/down sentence starts. Every coarse action clears fine focus, even at a document boundary where the selected reveal cannot move. The center is reserved and inert.

The ring/wheel is fine navigation: one fixed detent per eojeol/word, with no acceleration. From inactive focus, clockwise activates the current reveal's first token; counterclockwise activates its last token. Subsequent detents advance or regress one token. Crossing the last/first token enters the neighboring reveal and selects its first/last token. Document ends clamp. The reveal stays fully visible; this is not single-word replacement or timed RSVP.

## State and token model

ReadingUnit owns ordered original tokens with normalized-source UTF-16 ranges, within-line ranges and measured x/width. Rendering never performs independent tokenization. Korean uses whitespace-delimited eojeol; English uses the same word-like unit without morphological or semantic parsing.

ReaderStore adds a nullable focusedTokenIndex and derives focusedToken from the current reveal. Native fine movement uses cumulative document-token offsets and a binary lookup to cross reveals without skipping. The HTML stores a nullable per-reveal focus and traverses the same structured tokens.

Focus is transient and is not encoded in saved state. It resets on coarse navigation, source replacement and reflow. Changing the highlight style preserves it. There is no Word Focus ON/OFF setting. The existing delayed task only writes reading position; it never advances focus.

Retired alignment settings are absent from current model/UI/geometry/serialization. Older saved JSON unknown keys are ignored and disappear on the next save, preserving source and coarse location. No dormant gaze mode remains.

## Five visual conditions

Yellow background, text color, underline, dim others and black background / white text are selectable in Settings. All use the same regular-font shaped line, fixed baseline and token rectangles. Native rendering uses CoreText in a Canvas, drawing the full line once and clipping color overlays to the selected token. High contrast uses a dark background and white glyphs. Web and full/horizontal rich rendering also use a black token background with white glyphs; the earlier clipped-stroke variant was retired after owner feedback. Neither changes glyph widths or chunks. Dim others uses approximately 25–28% opacity while retaining every current token.

The full panel-pixel layer is scaled for phone previews, preserving measured font metrics. Oversized indivisible eojeol still use the previous smaller-font exception; extremely long unbroken tokens may become too small to read comfortably.

## Validation and next experiment

See VERIFICATION.md for actual results. Test left/right coarse reading without the ring, then use fine focus only when it helps. Compare styles for readability and effort; no winning style or comprehension benefit is assumed. Physical ring force/detents and TFT contrast still differ from a phone.
