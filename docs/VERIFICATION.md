# Verification — 2026-10-03

This is a behavioral prototype, not evidence that fixed-focus reading improves comprehension.

## Completed build checks

- Xcode 27.0, minimum deployment iOS 17.
- Debug simulator build/install/launch succeeded.
- Release generic iOS build without signing succeeded. This verifies device compilation, not installation.
- Physical signing attempt failed: Xcode has no configured Apple account and no matching app development provisioning profile. An existing development certificate alone is insufficient.
- Registered iPhone was unavailable; no installation or physical haptic/grip/calibration verification claimed.

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

## Visual evidence

`home-iphone17.png`, `home-13mini.png` and `settings-iphone17.png` are actual simulator screenshots, not generated design references. Both phone sizes were inspected: inset display, ivory wheel and settings entry fit without overlap. The iPhone 17 screenshot shows previously revealed text fading above the current line. The approved image is in `../design/approved-home.png`.

The app draws materials and controls natively. No flattened generated screenshot is used as the home UI. The live text is expected to differ from the concept image because segmentation follows rendered font width; physical panel geometry is a setting.

## Limits

- Physical panel mode requires a real ruler and user calibration on the actual iPhone. It is approximate; if the desired width exceeds the phone viewport, the home explicitly reports fit scaling.
- Phone haptics and touch do not reproduce a mechanical wheel's force, detents or final grip.
- Panel parts/prices are historical references, not a purchase-ready electrical/mechanical fit proof.
- Text import is plain UTF-8/UTF-16 TXT; at most 200,000 UTF-16 code units (oversized files/drafts are rejected visibly). No PDF/EPUB.
- Empty documents keep navigation safe and show a settings prompt. A single grapheme wider than the lane remains intact; no visual squeeze or Unicode corruption.
- State is local Application Support, not cloud or repo. Documents is exposed in Files for text transfer; saved reading state is not in that shared folder.
