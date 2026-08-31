# Virtual Display Sharing Implementation

## BetterDisplay Reference

BetterDisplay exposes two related ideas:

- OS-level virtual screens: user-created displays that appear in macOS Displays settings.
- PIP/streaming: a rendered view of a real or virtual display that can be shown somewhere else.

References:

- BetterDisplay README: https://github.com/waydabber/BetterDisplay
- BetterDisplay integration wiki: https://github.com/waydabber/BetterDisplay/wiki/Integration-features%2C-CLI
- BetterDummy open-source branch: https://github.com/ZhipingYang/BetterDummy/tree/opensource
- BetterDummy `Dummy.swift`: https://github.com/ZhipingYang/BetterDummy/blob/opensource/BetterDummy/Model/Dummy.swift

The public BetterDisplay repository is primarily release/docs content. The older open-source BetterDummy branch shows the OS-level display approach: create a `CGVirtualDisplayDescriptor`, set display metadata, create `CGVirtualDisplay`, then apply `CGVirtualDisplaySettings` with HiDPI modes.

That API is private CoreGraphics surface area. It is useful as architectural reference, but shipping it in WindowSnap would create review, compatibility, and signing risk.

## WindowSnap Approach

WindowSnap already has the streaming half:

- `RegionSelectionOverlayWindow` selects a source rectangle.
- `RegionCaptureEngine` captures the selected display with ScreenCaptureKit.
- `RegionMirrorWindow` renders frames into an `NSImageView`.

The first implementation keeps that pipeline and adds a share-optimized presentation mode:

- `RegionSharePresentationMode.floatingMirror` keeps the existing window behavior.
- `RegionSharePresentationMode.virtualDisplayWindow` opens the same captured region in a stable window titled `WindowSnap Virtual Display`.
- Video apps can select that exact window from their window-sharing picker.
- The share window keeps the selected region's aspect ratio via `contentAspectRatio`.

This gives users the practical BetterDisplay-style sharing workflow without depending on private virtual-display APIs.

## Virtual Camera Implementation

The production-safe camera path is now split into three pieces:

- Host capture: `RegionCaptureEngine` crops the selected region and publishes a `CVPixelBuffer` to `RegionFrameSink`.
- Shared transport: `RegionFrameHub` writes the latest BGRA frame and JSON metadata into the app group container.
- Camera extension: `WindowSnapVirtualCameraExtension` reads the shared frame, letterboxes it into 1280x720 or 1920x1080, and publishes it as `WindowSnap Virtual Camera` through CoreMediaIO.

The host app activates the system extension with `OSSystemExtensionRequest.activationRequest`. Activation only succeeds for a signed app bundle with the extension embedded at `Contents/Library/SystemExtensions`.

For SwiftPM distribution builds, set:

```bash
BUILD_VIRTUAL_CAMERA_EXTENSION=1 CODESIGN_ID='Developer ID Application: Your Name (TEAMID)' ./scripts/build-universal-bundle.sh
```

The standalone extension build script is:

```bash
./scripts/build-virtual-camera-extension.sh
```

Development builds without `BUILD_VIRTUAL_CAMERA_EXTENSION=1` still support the fallback share window named `WindowSnap Virtual Display`.

## Remaining Signing Work

Camera extension activation is controlled by macOS and Apple Developer entitlements. Before release:

1. Add the host app and extension identifiers in the Apple Developer portal.
2. Add matching App Groups capability to both identifiers.
3. Add System Extension capability to the host app identifier.
4. Confirm the Team ID-expanded Mach service and app group values required by the signing profile.
5. Build a signed app with `BUILD_VIRTUAL_CAMERA_EXTENSION=1`, move it to `/Applications`, launch it, approve the extension in System Settings, then verify the camera appears in FaceTime/Photo Booth/Zoom.

## Future OS Virtual Display Path

To appear as a true macOS display:

1. Build a guarded adapter around `CGVirtualDisplayDescriptor`, `CGVirtualDisplay`, `CGVirtualDisplayMode`, and `CGVirtualDisplaySettings`.
2. Create modes from common aspect ratios and the selected region dimensions.
3. Store serial/product identifiers so virtual displays restore predictably.
4. Decide whether WindowSnap renders into the virtual display, mirrors it, or only manages it.
5. Add sleep/wake recovery. BetterDisplay/BetterDummy release notes and docs call out macOS sleep issues around mirrored virtual displays.

This should remain behind an experimental flag unless the project intentionally accepts private API risk.
