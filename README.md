# Infinite Terrarium

An offline, AI-assisted digital ecosystem playground built for Swift Student Challenge style constraints.

## What This App Does

`Infinite Terrarium` simulates hundreds to thousands of organisms in real time and lets you intervene with three core actions:

- `Feed`: tap the simulation surface to inject local energy.
- `Mutate`: retune the dominant lineage DNA (behavior parameters).
- `Analyze`: ask the on-device model to explain current ecosystem dynamics.

The app combines:

- Boids-style flocking + Quadtree neighbor lookup for simulation
- SwiftUI + shader-based rendering for liquid/glass-like visuals
- Foundation Models (on-device) for DNA generation and ecosystem explanation

## Platform and Requirements

- Target: iOS 26.0+
- Device families: iPhone and iPad
- Orientation: landscape left/right
- Mac Catalyst: supported (desktop testing/build path)
- Xcode: Xcode 26 recommended (required for full Foundation Models path)

Notes:

- AI features require Foundation Models availability on device/OS.
- AI requires macOS 26+ with Apple Intelligence and Foundation Models availability.
- If Foundation Models is unavailable, the app returns explicit unavailable messages (no cloud fallback so AI analysis and inject species will not be available).

## Run the Project

### Option 1: Xcode (recommended)

1. Open Xcode.
2. Open folder: `The-Infinite-Terrarium.swiftpm`
3. Select scheme: `Infinite Terrarium`
4. Run on an iOS simulator or device.

### Option 2: CLI build

```bash
cd The-Infinite-Terrarium.swiftpm
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -scheme "Infinite Terrarium" -destination "generic/platform=iOS" build
```

### Option 3: CLI build (Mac Catalyst)

```bash
cd The-Infinite-Terrarium.swiftpm
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -scheme "Infinite Terrarium" \
  -destination "generic/platform=macOS,variant=Mac Catalyst" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

## Controls and HUD

- Tap canvas: `Feed` (local pulse, not a toolbar button)
- Bottom toolbar:
  - `Mutate`
  - `Analyze`
  - `Guide`
- Analyze panel:
  - `Analyze` for explanation
  - `Inject Species` for AI-generated species batch
- HUD metrics:
  - `FPS`, `Sim`, `Render`
  - `Population`, `Avg Energy`, `At Risk`
  - Adaptive quality tier

## Repository Layout

- `The-Infinite-Terrarium.swiftpm/`: active app workspace (main entry)
- `The-Infinite-Terrarium.swiftpm/Sources/`: app source code
- `The-Infinite-Terrarium.swiftpm/Vendor/MarkdownPackages/`: vendored markdown dependencies
- `LegacyXcodeProject/`: archived legacy Xcode project (not the primary development path)

## Open Source Dependencies

Direct and transitive dependencies used in the current SwiftPM app:

- `swift-markdown-ui` (MIT): https://github.com/gonzalezreal/swift-markdown-ui
- `NetworkImage` (MIT): https://github.com/gonzalezreal/NetworkImage
- `cmark-gfm` (BSD-2-Clause): https://github.com/github/cmark-gfm
