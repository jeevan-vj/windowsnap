# App configuration contract

`VERSION` is the authoritative marketing version and `BUILD_NUMBER` is the
authoritative monotonically increasing production build number. The values in
`WindowSnap/App/Info.plist` are reviewed mirrors so the source plist is useful
outside the packaging scripts. `scripts/bump-version.sh` updates all four
values together. Every production release must use a build number greater than
the previously published release.

`scripts/validate-configuration.sh` validates the source contract. Passing
`--bundle path/to/WindowSnap.app` additionally validates the packaged plist.
Both bundle builders run this check and modify only the copied plist; a build
must never dirty the source template.

## Reviewed Info.plist keys

- `CFBundleDisplayName`, `CFBundleName`, `CFBundleExecutable`,
  `CFBundleIdentifier`, and `CFBundlePackageType` identify the app to macOS.
- `CFBundleIconFile` selects the compiled AppIcon asset.
- `CFBundleShortVersionString` and `CFBundleVersion` expose the reviewed release
  metadata.
- `LSMinimumSystemVersion` matches SwiftPM and asset compilation at macOS 13.0.
- `LSUIElement` makes WindowSnap a menu-bar app without a Dock icon.
- `NSPrincipalClass` selects AppKit's application class for programmatic launch.
- `NSScreenCaptureUsageDescription` is required only when the user invokes
  Region Share. Accessibility consent is explained by the in-app onboarding UI
  because macOS has no recognized Accessibility usage-description plist key.
- `NSHumanReadableCopyright` is displayed by standard macOS metadata surfaces.

WindowSnap has no storyboard, login-helper plist switch, Apple Events code path,
or App Sandbox entitlement. `WindowSnap.entitlements` is therefore intentionally
empty. Accessibility and Screen Recording are privacy permissions granted by
the user at runtime, not code-signing entitlements.

## Debug and production signing

Local bundle scripts may ad-hoc sign for development. The canonical
`scripts/release.sh` path requires Developer ID, Hardened Runtime, notarization,
stapling, and verification. Both paths use the same least-privilege entitlement
file; production never gains broader entitlements than debug builds.
