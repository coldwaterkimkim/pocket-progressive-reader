# Horizontal Rail vertical centering — 2026-10-07

The single line is now vertically centered as well as horizontally focus-centered. A non-shrinking document strip preserves inline Markdown structure. Automatic WebKit text enlargement is disabled so the configured font size remains unchanged.

Live Chromium checked four viewport heights (76/120/200/240) with plain text and Markdown: 32 token positions, vertical strip center error 0px and horizontal error below 0.5px. Web fixture checks pass. The relevant native Full/Horizontal UI test passed after the final text-size correction (`test_sim_2026-10-07T14-37-00-970Z_pid93255_a04f4570.xcresult`); the exported `rail-center-native.png` was visually inspected. Final signed Release build, iPhone 13 mini installation and launch succeeded. Temporary browser/server stopped.

---

# Black focus and centered Horizontal Rail — 2026-10-07

- Restored black token background / white glyphs in native chunks, Full/horizontal rich rendering and web Canvas. Settings label is `검은 배경`; stored `highContrast` values remain compatible. No glyph-width changes.
- Horizontal Rail now snaps the selected token's visual center to the viewport center on every navigation change, including first/last tokens via end spacers. While fine focus is active, direct panning is disabled. Vertical Full retains nearest-edge scrolling.
- Live Chromium: 120 forward/reverse checks across three widths, two preview scales and plain/Markdown, maximum visual center error 0.4453125px (scroll-offset pixel rounding). A further 25 checks cover all five styles and a token split across inline Markdown spans, maximum error 0.3203125px. Black/white computed colors and unchanged vertical behavior confirmed. `rail-center-web-checks.json` records results.
- Web fixture tests passed. Relevant native Full/Horizontal UI flow passed after black-color restoration and again after centered rail changes. Final result: `test_sim_2026-10-07T14-29-53-274Z_pid93255_125be0a7.xcresult`. Both Full black-focus and centered-rail screenshots were exported and visually inspected (`black-focus-native-full.png`, `rail-center-native.png`). This is a focused UI rerun, not a new complete suite run.
- Final signed Release build succeeded; installed and launched on iPhone 13 mini. Physical tactile/reading benefit still needs owner hands-on testing. Temporary browser/server stopped.

---

# Whole-document and viewport verification — 2026-10-07

Current behavior is defined by FULL_DOCUMENT_REVISION.md; older evidence below is historical.

- 30 native engine/store/source tests passed, with the final changed coarse-navigation test rerun successfully. Coverage adds whole-document construction, retired sentence-mode migration and stationary visible-window CCW regression.
- Four distinct relevant UI tests passed across focused runs: Full Markdown / horizontal views, CCW within visible rows, Current Only / past positioning, and five highlight styles with stable line geometry. This is not a new complete UI-suite run.
- The first run passed 32 checks (30 logic + two UI). The final follow-up passed four checks (one changed logic + three UI). Result bundles: `test_sim_2026-10-07T14-15-32-884Z_pid93255_ab67d23d.xcresult` and `test_sim_2026-10-07T14-18-04-731Z_pid93255_f1ff3216.xcresult` in the local XcodeBuildMCP directory.
- The native UI test confirms actual WK document title text, takes formatted and scrolled screenshots, uses a sentence button, vertically scrolls, switches to horizontal, swipes, and activates fine focus. Exported screenshots `full-native-markdown.png` and `full-native-scroll.png` were visually inspected.
- Web fixture tests pass. Live Chromium verifies Markdown heading/emphasis/list/quote/code/table/task structure, no eager external-image load, token enumeration, vertical overflow, one unwrapped horizontal line, coarse target scrolling, highlight clearing, and stationary reverse focus within the current viewport. The hardware lab confirms a 480×200 document surface, 113 tokens, overflow and stable reverse focus. Record: `full-web-checks.json`. Only the localhost favicon returned 404.
- Final signed Release build succeeded. Installed and launched on the connected iPhone 13 mini; device process inspection confirmed PocketReader running. The temporary browser and local server were stopped.

Limits: Full/horizontal render GFM Markdown; progressive chunks remain normalized plain text. No math/Mermaid engine. Remote images need an explicit tap; image download failure paths and external link destinations were not exercised. Simulator/browser checks do not demonstrate physical encoder feel, readability benefit or comprehension gains. Historical practical memory/font-shrink limits remain.

---

# Current manual word-focus verification — 2026-10-07

Current reading behavior is defined by WORD_FOCUS_REVISION.md. The earlier gaze evidence below is historical; gaze UI/state/geometry has been removed from product code.

- 28 native engine/store/normalization tests passed. Tests verify original-token UTF-16 ranges and measured positions, normal-left lane fit over 54 panel/chunker/font combinations, five-style geometry invariance, first/last implicit activation, complete forward/backward traversal, bounds including extreme deltas, coarse no-op focus clearing, sentence-history reset, transient focus, old JSON migration, TXT/MD normalization and large input.
- All 11 native UI tests passed, with zero failures and zero runtime warnings in the xcresult summary. The MCP call itself timed out after 300 seconds; the underlying Xcode run completed successfully at approximately 319 seconds. Actual result bundle and log were inspected rather than inferring success from that timeout.
- UI checks cover ring activation/regression/coarse reset, all five styles with constant current-line frame, no retired settings, presentation positions, manual reveal/sentence navigation, draft apply/discard, real TXT/MD Files imports, font reflow and progress/panel behavior.
- Exported native style screenshots are `word-focus-native-{yellow,color,underline,dim,contrast}.png`. Each was visually inspected: the whole current line remains readable and stationary, with only the selected token's appearance changed.
- Web fixture checks passed (`node tests/web-reader.test.mjs`): structured original tokens, 18 panel/chunker combinations, fine traversal, no future, reset, all five styles, source normalization and large import.
- Live Chromium exercised 12 eojeol across reveal/sentence boundaries in both directions, reverse initial activation, document start, coarse reset, center reservation and five stationary drawing styles; no failures. All five actual Canvas style screenshots were inspected. Evidence is in `word-focus-web-checks.json` and `word-focus-web-*.png`.
- Signed Release build succeeded, and the revised app was installed and launched on the connected iPhone 13 mini. Device tooling confirmed its running process. No real reading-session benefit or final hardware equivalence is claimed.

Native unit result: `test_sim_2026-10-07T10-08-15-344Z_pid93255_117b2e4f.xcresult`. UI result: `test_sim_2026-10-07T10-08-53-856Z_pid93255_310e800a.xcresult` (local XcodeBuildMCP result-bundles directory).

Next experiments: compare coarse reading without the ring against occasional fine assistance; compare highlight styles for comfort. Actual TFT contrast and encoder feel differ from iPhone. The previous very-long-eojeol font shrink and practical memory/normalization limitations remain.

---

# Latest revision verification — 2026-10-07

The earlier evidence below concerns the original 2026-10-03 build. Reading behavior is now defined in `READING_REVISION.md`.

- All 23 native engine/store/normalization tests passed on iPhone 17 Simulator. Coverage includes 162 panel/algorithm/anchor/font combinations, final ink bounds and first-eojeol center, indivisible Unicode tokens, centered/current and bottom/typewriter geometry, 200k-plus text, normalization, UTF-8/UTF-16, source format persistence and old-settings migration.
- Nine UI flows passed in the first revision run. After ink-metrics and Markdown improvements, three focused UI flows passed alongside the 23 unit checks: centered/bottom positioning, actual system Files Markdown import through normalized reading, and Markdown paste / anchor adjustment / regression. After the final whole-layer preview-scaling correction, all three relevant UI checks passed again: centered/bottom positions, font reflow/control fit, and Markdown paste / fixed first-eojeol anchor / slider movement / regression. Ten distinct UI tests passed across these focused runs; this was not a single combined 33-test run.
- `node tests/web-reader.test.mjs` passed: deterministic Canvas fixture across 108 geometry combinations, nonlinear font fallback, normalization, structure, history/regression, 200k-plus file ingestion and fixed editor CSS.
- Live Chromium Canvas checks passed across 63 panel/algorithm/anchor combinations and 2,311 displayed units, with 0 measured first-eojeol center error and no horizontal overflow. A 250,000-character source left the editor at 180px. The only browser console error was the local server's missing favicon. Real browser checking complements, rather than replaces, fixture checks.
- `revision-current-anchor.png` and `revision-past-anchor.png` are inspected native simulator screenshots of the final render path using temporary sample text. Original simulator saved state was restored afterward. `revision-web-current.png` and `revision-web-checks.json` retain live web evidence.
- Signed Release compilation succeeded. On 2026-10-07 the revised build was installed and launched on the connected iPhone 13 mini; system device tooling confirmed its running process. Hands-on gaze, grip, haptics and calibration checks remain.

Remaining experiment limits: very long unbroken eojeol become very small; Markdown is an MVP normalizer, not full CommonMark; practical memory/processing limits remain without an arbitrary app cap; fonts and optical characteristics differ from final TFT hardware; software tests do not demonstrate comprehension or attention gains.

---

# Verification — 2026-10-03

This is a behavioral prototype, not evidence that fixed-focus reading improves comprehension.

## Completed build checks

- Xcode 27.0, minimum deployment iOS 17.
- Debug simulator build/install/launch succeeded.
- Release generic iOS build without signing succeeded. This verifies device compilation, not installation.
- Earlier signing attempt failed and the iPhone was unavailable. After connection, the correct development team from the certificate organization unit was supplied as a local build override.
- Signed Release build succeeded for the connected iPhone 13 mini. System device tooling confirmed installation, successful launch and a running PocketReader process.
- Physical haptics, grip, calibration and visible UI have not been independently verified; those need hands-on checking on the phone.

## Automated behavior

All 10 engine/store tests passed in the final unit run: native width/content preservation across three algorithms, grapheme-safe long tokens, empty input, bounded navigation, sentence history reset, reflow at duplicate text source offsets, persistence restoration, explicit pending-save flush, delayed latest-position save and sample-mode isolation.

All seven UI tests passed across focused simulator runs after corrections (not a single combined 17-test run):

| Flow | Result |
| --- | --- |
| Directional chunk/sentence navigation, no future leak | Pass |
| Ring drag both directions, fixed current baseline | Pass |
| Three display modes preserve current and hide future | Pass |
| Progress preserves baseline, panel changes geometry | Pass |
| Font reflow and home controls fit screen | Pass |
| Text draft requires apply; discard preserves source | Pass |
| Actual system Files picker TXT import, apply and reading | Pass |

Initial runs exposed test query instability in native text menus, Stepper and Files grid cells. Final tests target accessible controls and the actual file cell. The settings draft is initialized once per sheet, and closing a dirty draft explicitly supports continue/apply/discard. Navigation saves are coalesced for 250ms and flushed on lifecycle transitions.

Normal-launch simulator smoke check also passed: moved from position 2/18 to 3/18, terminated and relaunched the app, and observed position 3/18 restored. Existing saved font settings were preserved.

## Visual evidence (original build)

`home-iphone17.png`, `home-13mini.png` and `settings-iphone17.png` are actual simulator screenshots, not generated design references. Both phone sizes were inspected: inset display, ivory wheel and settings entry fit without overlap. The iPhone 17 screenshot shows previously revealed text fading above the current line. The approved image is in `../design/approved-home.png`.

The app draws materials and controls natively. No flattened generated screenshot is used as the home UI. The live text is expected to differ from the concept image because segmentation follows rendered font width; physical panel geometry is a setting.

## Limits

- Physical panel mode requires a real ruler and user calibration on the actual iPhone. It is approximate; if the desired width exceeds the phone viewport, the home explicitly reports fit scaling.
- Phone haptics and touch do not reproduce a mechanical wheel's force, detents or final grip.
- Panel parts/prices are historical references, not a purchase-ready electrical/mechanical fit proof.
- Historical build: TXT had an application cap. This was removed in the 2026-10-07 revision, which adds Markdown; no PDF/EPUB.
- Empty documents keep navigation safe and show a settings prompt. A single grapheme wider than the lane remains intact; no visual squeeze or Unicode corruption.
- State is local Application Support, not cloud or repo. Documents is exposed in Files for text transfer; saved reading state is not in that shared folder.
