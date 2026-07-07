# Intel Mac Compatibility Notes

## Context

WindowSnap is distributed as a macOS app and must run natively on both Apple Silicon and Intel Macs. The correct distribution artifact is a universal app bundle whose executable contains both `arm64` and `x86_64` slices.

## Decisions Made

### Keep Distribution Builds Universal

`scripts/build_bundle.sh` now delegates to `scripts/build-universal-bundle.sh`.

Reason: older scripts and release helpers call `build_bundle.sh`. Leaving it as a current-host build path made it easy to accidentally ship an Apple-Silicon-only app from an Apple Silicon machine. Delegating keeps backward compatibility for callers while making the safer universal build the default.

### Build From the Package Root

`scripts/build-universal.sh` now changes directory to the package root before running `swift build`.

Reason: the script computes `ROOT_DIR`, but SwiftPM commands previously depended on the caller's current directory. Running the script from the repository root, another script, or CI could fail or build from the wrong location. Building from `ROOT_DIR` makes the script location-independent.

### Make Sparkle Optional at Compile Time

`WindowSnap/Core/UpdateManager.swift` guards Sparkle usage with `#if canImport(Sparkle)`.

Reason: `UpdateManager.swift` imports Sparkle, but the current SwiftPM manifest does not declare a Sparkle dependency. That caused `swift build --arch x86_64` to fail with `no such module 'Sparkle'`. The guard keeps the app compiling on both architectures when Sparkle is not linked. If Sparkle is added to `Package.swift` later, the same code path enables the updater automatically.

## Verification Commands

Run from the repository root:

```bash
swift build --package-path WindowSnap -c release --arch x86_64 --product WindowSnap
```

Expected result: build completes successfully. Existing Swift 6 concurrency/deprecation warnings may appear, but there should be no `no such module 'Sparkle'` error.

Build the release-style universal bundle:

```bash
WindowSnap/scripts/build-universal-bundle.sh
```

Verify the installed or built app has both architecture slices:

```bash
lipo -info WindowSnap/dist/WindowSnap.app/Contents/MacOS/WindowSnap
```

Expected output includes:

```text
x86_64 arm64
```

## Install And Run Locally

After building:

```bash
ditto WindowSnap/dist/WindowSnap.app /Applications/WindowSnap.app
open /Applications/WindowSnap.app
```

If replacing an existing install, remove the old app first:

```bash
rm -rf /Applications/WindowSnap.app
ditto WindowSnap/dist/WindowSnap.app /Applications/WindowSnap.app
```

## Notes For Future Agents

- Do not reintroduce a single-architecture distribution path unless it is clearly named as such.
- Keep `build_bundle.sh` as a compatibility entrypoint for existing docs and release scripts.
- If Sparkle is properly added to `Package.swift`, preserve Intel verification before removing any `canImport(Sparkle)` fallback.
- The generated app in `WindowSnap/dist` and SwiftPM outputs in `WindowSnap/.build` are build artifacts; avoid committing them unless release policy changes.
