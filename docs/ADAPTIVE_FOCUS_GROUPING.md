# Adaptive Focus Grouping — 2026-10-08

Owner decision: reduce excessively fine attention changes from short eojeol while keeping reveal segmentation unchanged.

## Interaction

Word Focus adds Minimum Focus Length (`최소 포커스 길이`) 1/2/3/4, default3 including existing saves without the field. One means the original one-token baseline, including punctuation-only tokens. The 15-degree wheel detent now advances one precomputed group. CW and CCW traverse the same ordered sequence. Coarse buttons still clear focus.

Example minimum3: `[오늘이] [어제보다] [더 많이] [배고프다.]`. All five styles emphasize the complete range, including the intervening space. Horizontal Rail centers the entire group's visual width while keeping its vertical center. Existing Context Margin, panel geometry, TXT/MD source editing and full/scroll modes remain.

## Representation and deterministic algorithm

Immutable reveal units retain their original tokens and boundaries. ReaderStore has a parallel `focusGroups` array keyed by reveal index. Each FocusGroup is a contiguous start/end-exclusive token range. Group-prefix indices support bounded binary-search navigation; no grouping mutations happen during wheel input.

Meaningful length counts Unicode grapheme clusters and excludes whitespace/punctuation. Eojeol are atomic. For minimum2–4, a short leading token collects following tokens until the minimum is met, a hard boundary is reached, or three tokens are included. An undersized final group joins the preceding group if their combined count fits three and stays in the same boundary. Otherwise it remains undersized. Already-long leading tokens stay alone. This linear greedy algorithm makes the forward preference explicit and keeps runtime small; there is no LLM, morphology or new NLP dependency.

Chunk views group independently within each reveal (which already belongs to a sentence). Full/rail retain their single whole-document unit, with sentence and structural-block hard breaks supplied separately. The shared DOM index reports token break-before indices for original blocks/newlines and sentence spans. Native unions these with its existing sentence segmentation. Table cells/list items remain boundaries.

Changing the setting recomputes groups around the existing focused token; the current reveal and visible viewport remain, and the group containing that token becomes active. Fine focus itself remains transient. Persisted source/position and settings format are preserved.

## Rendering

Native CoreText clips over the range from first token.x to last token.endX, retaining the same shaped line/font. Group background and underline include inter-token whitespace and existing side padding. Full/rail use retained DOM text nodes and Range rectangles: a paint-only layer fills the range while token classes supply text color/dimming/white ink. Markdown inline runs remain intact. No per-focus source reconstruction or width changes.

## Limits and next experiment

Minimum length is soft; sentence/reveal/structure integrity and max3 tokens take precedence. It measures characters, not linguistic or semantic coherence. Very long atomic tokens are not split and may remain visually large; existing font fallback remains. Sentence parsing follows the existing platform segmenters, so unusual abbreviations/quotation edge cases may differ. Compare minimum1/2/3/4 for comfort before changing reveal segmentation. Software checks do not establish attention/comprehension benefit.
