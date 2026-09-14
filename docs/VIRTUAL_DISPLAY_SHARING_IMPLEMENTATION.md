# Virtual Display Sharing Implementation

WindowSnap has two share surfaces plus an optional virtual camera:

1. **Region Share** — crop a rectangle on a real display and mirror it into a window.
2. **Virtual Screen** — create a real extra macOS display (`WindowSnap Display`) using private `CGVirtualDisplay` SPI, then preview it with ScreenCaptureKit.
3. **Virtual Camera** — stream the selected region into `WindowSnap Virtual Camera`.

## Official Apple APIs

Public APIs cannot create a host virtual monitor. They only capture or reconfigure displays that already exist.

- **ScreenCaptureKit** is the supported capture path (`SCShareableContent` → `SCDisplay` → `SCStream`). It replaces `CGDisplayStream`, which the macOS 15 SDK marks unavailable.
- **Quartz Display Services** can change the mode of an existing `CGDirectDisplayID`.
- **Virtualization.framework** `VZGraphicsDisplay` is a guest VM scanout, not a desktop display.
- **DriverKit** is the only official way to create a display, and it is a signed driver project.

## Virtual Screen (DeskPad path)

Creation uses undocumented CoreGraphics SPI, the same family DeskPad, BetterDisplay, BetterDummy, and Chromium use:

`CGVirtualDisplayDescriptor` → `CGVirtualDisplay` → `CGVirtualDisplaySettings` / `CGVirtualDisplayMode`

Declarations live in `WindowSnap/CVirtualDisplay/include/CGVirtualDisplayPrivate.h`, derived from [Stengo/DeskPad](https://github.com/Stengo/DeskPad) (MIT; originally VirtualDisplayExp by Khaos Tian). Runtime implementations are in system frameworks.

Swift isolation:

- `VirtualDisplayAdapter` is the only Swift type that imports `CVirtualDisplay`. It feature-detects with `NSClassFromString` before use, uses a dedicated serial queue, and keeps a strong `CGVirtualDisplay` reference so releasing it unplugs the display.
- `VirtualDisplayController` waits until `NSScreen` lists the new `displayID`, then starts ScreenCaptureKit via `RegionCaptureEngine` and shows `VirtualDisplayMirrorWindow`.
- Stable vendor/product/serial IDs (`0x5753` / `0x5653` / `0x0001`) help macOS remember arrangement.

This is compatible with direct Developer ID / GitHub distribution. It is not App Store safe. If Apple removes the classes, Connect shows “unavailable” instead of crashing.

### How to share

- **Connect Virtual Screen**, then in Zoom/Meet/Teams share the **display** named `WindowSnap Display`, or share the preview window with the same title.
- Change resolution in System Settings → Displays. The preview window follows.
- Click the preview to teleport the cursor onto the virtual screen. A blue title bar means the cursor is already there.
- **Disconnect Virtual Screen** (or quit WindowSnap) unplugs the display.

Sleep/wake recovery recreates the display if its `displayID` vanished, and otherwise restarts capture.

## Region Share (public-API crop)

Unchanged:

- `RegionSelectionOverlayWindow` selects a source rectangle.
- `RegionCaptureEngine` captures the selected display with ScreenCaptureKit.
- `RegionMirrorWindow` titled `Region Share` or `WindowSnap Virtual Display` is what video apps pick for the crop workflow.

This does not create an extra desktop. It only mirrors a rectangle of an existing screen.

## Virtual Camera

- Host capture: `RegionCaptureEngine` crops the selected region and publishes a `CVPixelBuffer` to `RegionFrameSink`.
- Shared transport: `RegionFrameHub` writes the latest BGRA frame and JSON metadata into the app group container.
- Camera extension: `WindowSnapVirtualCameraExtension` letterboxes frames into 1280x720 or 1920x1080 and publishes `WindowSnap Virtual Camera` through CoreMediaIO.

For SwiftPM distribution builds:

```bash
BUILD_VIRTUAL_CAMERA_EXTENSION=1 CODESIGN_ID='Developer ID Application: Your Name (TEAMID)' ./scripts/build-universal-bundle.sh
```

## Remaining Signing Work

Camera extension activation still requires Apple Developer identifiers, App Groups, and System Extension capability. Virtual Screen does not use the camera extension.

## Out of scope

Multiple virtual screens, BetterDisplay PIP of arbitrary displays, DDC/HDR, DriverKit, and App Store distribution.
