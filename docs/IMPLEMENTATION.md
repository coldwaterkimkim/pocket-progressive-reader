# Native prototype decisions — 2026-10-03

## Owner-approved direction

- iPhone native SwiftUI instead of PWA; no change to the attention-routing hypothesis.
- Two surfaces: immediate reader home and utility settings sheet.
- Silver material, inset display and ivory click wheel follow approved-home.png.
- No name/title, library, session evaluation or analytics on home.
- Left/right = reveal units; up/down = adjacent sentence start; wheel scrub = fixed angular detents, no acceleration.
- Center is intentionally inert; it does not toggle progress or move the focus.
- Future content hidden; current line fixed at the bottom; past-only or sentence-bound history optional.
- Rendered pixel width and a user-calibrated physical-size mode; phone PPI is not inferred.
- Default font is 26 panel pixels. Current baseline reserves space for optional progress so toggling it cannot shift text.
- Text drafts require explicit apply; unfinished drafts offer continue/apply/discard. TXT transfer uses the system Files picker and the app's Documents folder; private saved reading state stays in Application Support.
- Navigation updates immediately and coalesces local writes for 250ms; settings changes and background transitions flush saved state.

## Reference implementation differences to correct

- v4 uses Canvas maxWidth which can squeeze a long token. Native engine must split at Unicode grapheme boundaries instead.
- Original userscript eojeol punctuation scores are 12/6; v4 uses 42/18. Native eojeol baseline uses original scores, then width refit; 3–5 is a preference, not an invariant.
- Source offsets must survive reflow, rather than searching for duplicate chunk strings.
- Progress toggling must not move the current line.
- Screen fit is not final hardware fit; panel references are not purchase-verified parts.

## Scope

Plain text import/paste, local state, three presentation and segmentation modes, panel presets, simple haptics, keep-awake during reading. No hardware connection, file-format conversion, account, sync, native distribution to other users, or market validation.
