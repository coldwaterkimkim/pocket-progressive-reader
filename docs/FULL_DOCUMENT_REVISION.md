# Full document and viewport revision — 2026-10-07

Owner decision: compare progressive reading against a normal whole-document reader, and add a single-line horizontal document view. The silver home and utility settings remain unchanged.

- Presentation modes: Current Only, accumulated past, single-line horizontal. Retired sentence-bounded settings migrate to accumulated past without discarding the saved source.
- Segmentation adds Full. Full renders the complete source with natural wrapping and vertical scrolling, without reveal gating. Horizontal renders the entire document on one unwrapped line regardless of chunk algorithm.
- Accumulated past uses equal contrast for every row. Its visible window and active reveal are separate: CCW moves through the existing rows, shifting the window only after crossing its top. The user-selected dim-others word style remains an explicit separate option.
- Wheel movements still activate transient eojeol focus. In whole-document views left/right move a word position, up/down move a sentence position; all buttons clear fine highlighting. Whole-document focus scrolls only when the target is outside the viewport.
- Full and horizontal use bundled GFM Markdown rendering: headings, emphasis, lists, blockquotes, fenced/inline code, tables, links, task markers and images. Horizontal flattens block layout while preserving inline styles. Remote images require an explicit load tap. Links open on a tap. Scripts and interactive embedded HTML are excluded. Math/Mermaid are not supported.
- Progressive chunk views continue the existing normalized plain-text rendering; they do not display Markdown block layout or inline typography. Raw Markdown stays editable and unchanged in source settings.
- No timer, WPM, library, account, hardware purchase or home redesign.

The implementation uses local WKWebView only inside the two whole-document display variants; the native controls/settings and CoreText progressive renderer remain. Shared local assets also power the hardware lab. Dependency versions and licenses are in licenses/THIRD_PARTY.md.

This supersedes sentence-bounded history, historical faded past, and the rule that regressions always replace the whole viewport. Historical handoff decisions remain as design evidence.
