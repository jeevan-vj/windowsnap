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

## Signing identity for local and QA builds

macOS stores the Screen Recording grant against the app's *code requirement*
(bundle ID **and** signing identity), not just its bundle ID. A grant for an
Apple Development-signed `dist/WindowSnap.app` does not apply to a Developer
ID-signed `/Applications/WindowSnap.app`, and an ad-hoc build changes identity
on every rebuild. tccd then logs `Failed to match existing code requirement`
for `kTCCServiceScreenCapture` and the prompt keeps coming back.

Local and dev builds therefore always sign with one stable identity, chosen by
`scripts/resolve-local-signing-identity.sh`:

1. `SIGNING_IDENTITY` (identity name or SHA-1 fingerprint), if set
2. the `Developer ID Application` identity for team `88282K637B`
   (override the team with `WINDOWSNAP_TEAM_ID`)
3. the first `Apple Development` identity

`build-universal-bundle.sh` (and `build_bundle.sh` / `quick-install.sh`) and
`quick-run.sh` use it whenever `CODESIGN_ID` is not set, and derive `TEAM_ID`
from the identity name. When several identities share a name, the SHA-1 is
used so `codesign` is not ambiguous.

```sh
# Default: Developer ID for 88282K637B if installed
./scripts/build-universal-bundle.sh

# Pin a specific identity
SIGNING_IDENTITY="Developer ID Application: Jeevan Wijerathna (88282K637B)" ./scripts/quick-run.sh

# Region Share QA: fail rather than fall back to ad-hoc
REGION_SHARE_QA=1 ./scripts/build-universal-bundle.sh
```

Ad-hoc builds print a warning. With `REGION_SHARE_QA=1` they are refused.
`build-adhoc-release.sh` sets `ALLOW_ADHOC=1` explicitly and refuses to run
under `REGION_SHARE_QA=1`. `quick-run.sh` no longer silently re-signs ad-hoc
when signing fails.

Pick **one** identity and one install location for QA. If you test from
`/Applications`, install a Developer ID build there and don't also grant
`dist/WindowSnap.app`.

At launch, and whenever the permission flow fails, WindowSnap logs the bundle
path, signing team (or ad-hoc), and preflight result under the `Permissions`
category. It warns when it is ad-hoc signed or running from outside
`/Applications`:

```sh
log stream --predicate 'subsystem == "com.jeevanwijerathna.windowsnap" AND category == "Permissions"' --info
codesign -dv --verbose=2 /Applications/WindowSnap.app 2>&1 | grep -E 'Authority|TeamIdentifier'
```

## Permission flow

- The state comes from `CGPreflightScreenCaptureAccess()` only. ScreenCaptureKit
  is never probed to decide permission state.
- `CGRequestScreenCaptureAccess()` runs only after an explicit user action,
  and at most once per launch.
- Requested this launch but preflight is still false → **Restart required**.
  *Restart WindowSnap* relaunches the same bundle and quits.
- Requested in an earlier launch but preflight is false → **recovery alert**
  (stale or mismatched grant), shown at most every 30 seconds. It offers
  *Open Settings* and *Restart WindowSnap*.

## Troubleshooting: permission keeps asking

1. Check which copy is running and how it is signed (see the log commands
   above). It should be `/Applications/WindowSnap.app` with
   `TeamIdentifier=88282K637B`.
2. Quit WindowSnap.
3. Open **System Settings > Privacy & Security > Screen & System Audio
   Recording**. Select every `WindowSnap` row and remove it with **−**.
4. Install a Developer ID-signed build in `/Applications` (for example
   `./scripts/build-universal-bundle.sh`, then copy `dist/WindowSnap.app`).
   Don't run other copies such as `dist/` or DerivedData builds.
5. Launch `/Applications/WindowSnap.app` and choose **Set Up…** in Region Share
   preferences. Allow it in the system prompt or Settings.
6. When WindowSnap shows **Restart required**, click **Restart WindowSnap**.

If it still fails, you can clear the stored decision for this bundle ID with
the command below. It is documented here for manual use only. No WindowSnap
script runs it.

```sh
tccutil reset ScreenCapture com.jeevanwijerathna.windowsnap
```

Then repeat steps 5–6. This also clears the grant for every other copy that
shares the bundle ID.
