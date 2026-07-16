# Signed GitHub Release Runbook

This runbook documents the exact commands for building, signing, notarizing, and publishing WindowSnap for both Apple Silicon and Intel Macs.

## Current Apple Developer Setup

- Apple ID: `jeevan90wijerathna@gmail.com`
- Team ID: `88282K637B`
- Registered Bundle ID: `com.jeevanwijerathna.windowsnap`
- Developer ID signing identity: `Developer ID Application: Jeevan Wijerathna (88282K637B)`
- Notary keychain profile name: `windowsnap-notary`

## 1. Verify Local Signing Assets

Run from anywhere:

```bash
security find-identity -v -p codesigning
```

Expected identity:

```text
Developer ID Application: Jeevan Wijerathna (88282K637B)
```

Verify the notary profile:

```bash
xcrun notarytool history --keychain-profile windowsnap-notary
```

If this returns `401 Invalid credentials`, refresh the profile with a new app-specific password.

## 2. Refresh Notary Credentials

Create a new app-specific password at:

```text
https://appleid.apple.com/
```

Then run this locally in Terminal. Do not commit or paste the password into chat or source files.

```bash
xcrun notarytool store-credentials windowsnap-notary \
  --apple-id "jeevan90wijerathna@gmail.com" \
  --team-id "88282K637B" \
  --password "APP_SPECIFIC_PASSWORD"
```

Verify:

```bash
xcrun notarytool history --keychain-profile windowsnap-notary
```

## 3. Run Tests

From the package directory:

```bash
cd /Users/jeevanwijerathna/Projects/windowsnap/WindowSnap
swift test
```

Expected result:

```text
Executed 68 tests, with 0 failures
```

## 4. Build And Sign Universal App

From the package directory:

```bash
cd /Users/jeevanwijerathna/Projects/windowsnap/WindowSnap
CODESIGN_ID="Developer ID Application: Jeevan Wijerathna (88282K637B)" \
bash scripts/build-universal-bundle.sh
```

Expected outputs:

```text
dist/WindowSnap.app
dist/WindowSnap.zip
```

Verify architectures:

```bash
lipo -info dist/WindowSnap.app/Contents/MacOS/WindowSnap
```

Expected output includes:

```text
x86_64 arm64
```

Verify signature:

```bash
codesign --verify --deep --strict --verbose=2 dist/WindowSnap.app
codesign -dvvv dist/WindowSnap.app
```

Expected identity details include:

```text
Identifier=com.jeevanwijerathna.windowsnap
Authority=Developer ID Application: Jeevan Wijerathna (88282K637B)
TeamIdentifier=88282K637B
```

Before notarization, Gatekeeper may reject with `Unnotarized Developer ID`:

```bash
spctl -a -vv dist/WindowSnap.app
```

That is expected until the next step is complete.

## 5. Sign And Notarize App

From the package directory:

```bash
cd /Users/jeevanwijerathna/Projects/windowsnap/WindowSnap
CODESIGN_ID="Developer ID Application: Jeevan Wijerathna (88282K637B)" \
NOTARY_PROFILE="windowsnap-notary" \
bash scripts/sign-and-notarize.sh
```

Expected outputs:

```text
dist/WindowSnap.app
dist/WindowSnap.zip
dist/NOTARIZATION_INFO.txt
```

Verify notarized app:

```bash
spctl -a -vv dist/WindowSnap.app
xcrun stapler validate dist/WindowSnap.app
```

## 6. Create Signed And Notarized DMG

From the package directory:

```bash
cd /Users/jeevanwijerathna/Projects/windowsnap/WindowSnap
CODESIGN_ID="Developer ID Application: Jeevan Wijerathna (88282K637B)" \
NOTARY_PROFILE="windowsnap-notary" \
bash scripts/create-signed-dmg.sh
```

Expected output:

```text
dist/WindowSnap-1.2.6-macOS-notarized.dmg
```

Verify DMG:

```bash
codesign --verify --verbose dist/WindowSnap-1.2.6-macOS-notarized.dmg
spctl -a -vv dist/WindowSnap-1.2.6-macOS-notarized.dmg
xcrun stapler validate dist/WindowSnap-1.2.6-macOS-notarized.dmg
```

## 7. Full Release Script

The all-in-one release command builds, signs, notarizes, creates the DMG, creates a ZIP, and opens a GitHub release.

Use a draft release first:

```bash
cd /Users/jeevanwijerathna/Projects/windowsnap/WindowSnap
CODESIGN_ID="Developer ID Application: Jeevan Wijerathna (88282K637B)" \
NOTARY_PROFILE="windowsnap-notary" \
bash scripts/release.sh patch --draft
```

Use `minor` or `major` instead of `patch` when appropriate:

```bash
bash scripts/release.sh minor --draft
bash scripts/release.sh major --draft
```

Publish a draft after manual verification:

```bash
gh release edit v1.2.7 --draft=false
```

## 8. Manual GitHub Release Commands

Check GitHub CLI auth:

```bash
gh auth status
```

Create a draft release manually:

```bash
cd /Users/jeevanwijerathna/Projects/windowsnap/WindowSnap
gh release create v1.2.7 \
  --draft \
  --title "v1.2.7 - Release" \
  --notes "Universal signed and notarized macOS release for Apple Silicon and Intel Macs." \
  dist/WindowSnap-1.2.7-macOS-notarized.dmg \
  dist/WindowSnap-1.2.7-macOS-notarized.zip
```

## 9. Final Smoke Test

Download the DMG from the draft GitHub release, then test:

```bash
hdiutil attach ~/Downloads/WindowSnap-1.2.7-macOS-notarized.dmg
cp -R /Volumes/WindowSnap/WindowSnap.app /Applications/
open /Applications/WindowSnap.app
```

Confirm:

- App launches from `/Applications`
- Menu bar icon is visible
- Clipboard history opens with `Command+Shift+V`
- App asks for Accessibility permissions as expected
- Gatekeeper does not show unidentified developer or malware warnings

Unmount:

```bash
hdiutil detach /Volumes/WindowSnap
```

