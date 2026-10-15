# Region Share Packaging

## Virtual camera extension

The virtual camera bundle identifier is controlled by one value:

```sh
WINDOWSNAP_VIRTUAL_CAMERA_ID=com.example.WindowSnap.VirtualCameraExtension
```

`scripts/build-virtual-camera-extension.sh` uses that value for the extension's
`CFBundleIdentifier`, product/bundle name, mach service suffix, and final
`<bundle-id>.systemextension` directory. The host stores the same value in its
Info.plist, which is what `VirtualCameraExtensionManager` uses for activation
and bundle discovery.

A signed build must provide both the signing identity and the ten-character
Apple Developer Team ID:

```sh
TEAM_ID=ABCDE12345 \
CODESIGN_ID="Developer ID Application: Example (ABCDE12345)" \
BUILD_VIRTUAL_CAMERA_EXTENSION=1 \
./scripts/build-universal-bundle.sh
```

The build fails early if `CODESIGN_ID` is set without `TEAM_ID`. For signed
builds, the script generates these identifiers:

- App group: `$TEAM_ID.$WINDOWSNAP_VIRTUAL_CAMERA_ID`
- Camera mach service: `$TEAM_ID.$WINDOWSNAP_VIRTUAL_CAMERA_ID`

The generated host entitlements are written to
`.build/virtual-camera-extension/WindowSnapVirtualCameraHost.entitlements` and
are selected automatically by `build-universal-bundle.sh`. Ad-hoc builds retain
the legacy `group.com.jeevanwijerathna.windowsnap` development app group.

## App Store build without private display SPI

Normal developer builds include `CVirtualDisplay` and the private
`CGVirtualDisplay` adapter. Build the App Store-safe variant with:

```sh
WINDOWSNAP_APP_STORE=1 swift build
WINDOWSNAP_APP_STORE=1 swift test
```

That environment variable removes the executable target's dependency on
`CVirtualDisplay`, defines `APP_STORE`, and compiles an adapter stub that reports
virtual displays as unavailable. The C target remains declared in the package
so the default developer build continues to support virtual displays.

Do not embed or otherwise link the `CVirtualDisplay` product in an App Store
archive. The virtual camera system extension is a separate feature and must
still be signed and provisioned with its required entitlements if it is shipped.
