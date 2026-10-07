# Reading experiment revision — 2026-10-07

Current owner instructions supersede the historical all-bottom-fixed / long-token-splitting decisions. The native app remains the primary phone prototype; the standalone v4 hardware lab implements the same experiment and retains its original hardware comparison controls. The ChatGPT userscript remains an unchanged historical baseline.

## Visible behavior

- Exactly three presentation modes: Current Only vertically centered, Past-only Typewriter bottom fixed with continuous past, Sentence-bounded Typewriter at the same bottom position with sentence history reset.
- Both horizontal modes available: left alignment and first-eojeol ink-center gaze alignment. Anchor defaults to 33% of usable width and is adjustable from 20% to 50%.
- No readable future, no scrolling transition, manual progression and regression remain.
- Source editor is a 180-point native / 180-pixel web scrollable viewport. Plain text and Markdown can be pasted or imported separately.
- Explicit application character/file-size rejection removed. Files and normalized documents still consume device memory; large sources can take noticeable processing time. This is not unlimited-size support.
- The silver native home, six active-area presets and calibrated physical-size mode remain. v4 keeps all seven researched panel/module entries, integrated board, MCU/wheel/battery comparisons, body envelope, compatibility warnings and credit-card calibration.

## Modules

Native:

1. `SourceIngestion`: security-scoped file reading, UTF-8/BOM UTF-16 decoding.
2. `SourceDocument` / `MarkdownNormalizer`: retain raw source and format separately from normalized text and UTF-16 structural block ranges.
3. `ReadingEngine.sentences`: sentence segmentation only, constrained to blocks. No semantic/syntactic parsing, API or LLM.
4. `ReadingEngine`: neighboring eojeol candidates; native pixel measurement; greedy / width-balanced / eojeol-count baseline.
5. `NativeTextMetrics` / `AnchorGeometry`: CoreText ink center and final lane bounds.
6. `ReaderStore` / `PresentationGeometry` / `ReaderDisplay`: progression, retained past, vertical positioning and native rendering.

The standalone HTML keeps equivalent ingestion, normalization, segmentation, geometry and rendering functions in one offline file. They are separate functions rather than one combined parser/render routine. Web Canvas and native CoreText fonts can produce different chunk boundaries; this is expected and prevents hard-coded character-width assumptions.

## Geometry and chunk scoring

The visible ink center of the first eojeol is measured with the same font used for rendering. In usable-lane coordinates:

`origin = usableWidth × anchorFraction − firstEojeolInkCenter`

Candidates must satisfy both final left and right bounds after that shift. Padding is added only when drawing. Native text is laid out at panel-pixel font size and the whole layer is scaled for preview; choosing a smaller preview font would change optical metrics and invalidate fit checks. There is no English ORP character-index formula. Previous lines use the same horizontal rule.

Visual Balanced minimizes squared visual-width deviation with a short-unit penalty, a modest per-unit cost, and small punctuation bonuses. Count penalties are reserved for the explicit eojeol baseline. DP uses bounded candidate lookahead and backpointers, not whole-path copies. No sentence meaning is analyzed.

An eojeol longer than the available lane cannot simultaneously remain atomic, retain the chosen font, keep the anchor and avoid overflow. The explicit exception is **single-eojeol font reduction**. Actual smaller-font metrics are remeasured by binary search because optical font sizing and emoji fallback are not linear. Ordinary multi-eojeol chunks keep the configured font. Extremely long unbroken tokens can become unreadably small; this is an experiment limitation, not a promise of comfortable reading.

## Markdown MVP

Headings, paragraphs, list items and blockquotes form structural blocks even without terminal punctuation. Standard emphasis and inline-code delimiters are removed, links retain labels while destinations are stripped, image alt text remains without image syntax, HTML tags/comments/script/style noise is removed, and common entities are normalized. Escaped literal punctuation and code content are preserved. Nested parentheses in link destinations are handled.

This is a readable-text normalization layer, not a full CommonMark renderer. Table layouts, complex nested list indentation and arbitrary HTML structure do not retain full rich-document semantics. Malformed markup may remain literal. No new dependency or backend is added.

## Existing state

Old saved settings decode missing alignment fields as left / 33%. Raw source, source format and normalized-source focus offsets are persisted locally. Source replacement/format application starts at the beginning; display/alignment reflow retains the normalized-source location. For legacy documents containing unusual whitespace, normalization may change the exact offset mapping. Presentation-only and calibration changes avoid unnecessary segmentation.

## Validation

See `VERIFICATION.md` for observed results. Checks establish software geometry and navigation behavior; they do not prove sustained attention or comprehension benefits. Compare left vs gaze alignment and centered-current vs bottom-history in actual reading before freezing hardware.
