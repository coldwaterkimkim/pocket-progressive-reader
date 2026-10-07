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
