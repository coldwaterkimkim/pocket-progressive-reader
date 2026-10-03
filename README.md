# Pocket Progressive Reader

Native iPhone behavioral prototype of a physical, fixed-focus reader. The home is a silver iPod Classic inspired instrument: inset display, ivory directional wheel, one settings entry. Settings use a plain iOS Form.

## Product context

Read [HANDOFF.md](HANDOFF.md) first. Its historical desktop lab and userscript are preserved as references. Current owner decisions supersede its PWA suggestion: SwiftUI, home + settings only, no title/library/session dashboard. The approved visual target is [docs/design/approved-home.png](docs/design/approved-home.png).

## Build

- Xcode with an iOS simulator; minimum iOS 17.
- Open `PocketReader.xcodeproj`, choose the `PocketReader` scheme and an iPhone simulator, then Run.
- Project generation (only needed after modifying project.yml): `xcodegen generate`.
- Physical device: select your own development team in Xcode Signing & Capabilities, connect and trust the iPhone, enable Developer Mode if prompted, then Run. Team IDs/profiles are not committed.

No backend, account, analytics, remote API, or external runtime dependency.

Implementation and verification are in progress; see `docs/IMPLEMENTATION.md` for the final state.
