# WindowSnap Distribution Guide

## The Gatekeeper Problem

When users try to open WindowSnap.app, they see:

> **"WindowSnap.app" Not Opened**  
> Apple could not verify "WindowSnap.app" is free of malware...

This happens because the app isn't **code signed** and **notarized** by Apple.

---

## User Workarounds (Until You Sign the App)

### Method 1: Right-Click Open (Easiest)
1. Right-click (or Control+click) on `WindowSnap.app`
2. Select "Open" from the menu
3. Click "Open" in the confirmation dialog
4. App will open and remember this choice

### Method 2: Remove Quarantine Flag
```bash
# For already installed app
xattr -d com.apple.quarantine /Applications/WindowSnap.app

# Or before installing
xattr -d com.apple.quarantine ~/Downloads/WindowSnap.app
```

### Method 3: System Settings (macOS Ventura+)
1. Try to open the app (it will be blocked)
2. Go to **System Settings** → **Privacy & Security**
3. Scroll down to see "WindowSnap was blocked"
4. Click **Open Anyway**

---

## Proper Solution: Code Signing & Notarization

To distribute without user warnings, you must:

### Prerequisites
1. **Apple Developer Account** ($99/year)
   - Sign up at https://developer.apple.com

2. **Developer ID Certificate**
   - In Xcode: Preferences → Accounts → Manage Certificates
   - Or create at https://developer.apple.com/account/resources/certificates

3. **App-Specific Password**
   - Create at https://appleid.apple.com
   - Account Settings → Security → App-Specific Passwords

### One-Time Setup

1. **Find your signing identity:**
```bash
security find-identity -v -p codesigning
```
Copy the full "Developer ID Application: Your Name (TEAMID)" string

2. **Create notarytool profile:**
```bash
xcrun notarytool store-credentials "windowsnap-notary" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"  # app-specific password
```

### Build, Sign & Notarize

```bash
# Set your credentials
export CODESIGN_ID="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="windowsnap-notary"

# Build with signing
cd WindowSnap
bash scripts/build_bundle.sh

# Sign and notarize
bash scripts/sign-and-notarize.sh
```

The script will:
1. ✅ Code sign with hardened runtime
2. ✅ Submit to Apple for notarization (~5-10 mins)
3. ✅ Staple the notarization ticket
4. ✅ Verify the app

After success, `dist/WindowSnap.app` will open on any Mac without warnings!

---

## Alternative: GitHub Actions Auto-Signing

Create `.github/workflows/release.yml`:

```yaml
name: Release
on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Import Code Signing Certificate
        env:
          CERTIFICATE_BASE64: ${{ secrets.CERTIFICATE_BASE64 }}
          CERTIFICATE_PASSWORD: ${{ secrets.CERTIFICATE_PASSWORD }}
        run: |
          echo "$CERTIFICATE_BASE64" | base64 --decode > certificate.p12
          security create-keychain -p actions build.keychain
          security unlock-keychain -p actions build.keychain
          security import certificate.p12 -k build.keychain -P "$CERTIFICATE_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k actions build.keychain
          rm certificate.p12
      
      - name: Build & Sign
        env:
          CODESIGN_ID: ${{ secrets.CODESIGN_ID }}
        run: |
          cd WindowSnap
          bash scripts/build_bundle.sh
      
      - name: Notarize
        env:
          NOTARY_PROFILE: ${{ secrets.NOTARY_PROFILE }}
        run: |
          cd WindowSnap
          bash scripts/sign-and-notarize.sh
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            WindowSnap/dist/WindowSnap.app
            WindowSnap/dist/WindowSnap.zip
            WindowSnap/dist/WindowSnap.dmg
```

Add secrets to GitHub:
- `CERTIFICATE_BASE64`: `base64 -i certificate.p12 | pbcopy`
- `CERTIFICATE_PASSWORD`: P12 export password
- `CODESIGN_ID`: "Developer ID Application: ..."
- `NOTARY_PROFILE`: (setup with `notarytool store-credentials`)

---

## Quick Reference

### Check if app is signed:
```bash
codesign --verify --verbose dist/WindowSnap.app
```

### Check notarization status:
```bash
spctl -a -vv dist/WindowSnap.app
```

### Get notarization logs:
```bash
xcrun notarytool log SUBMISSION_ID --keychain-profile windowsnap-notary
```

### Remove old signatures:
```bash
codesign --remove-signature dist/WindowSnap.app
```

---

## Cost-Free Alternative: Open Source Distribution

If you don't want to pay $99/year:

1. **Add clear instructions** in README:
   - "Right-click → Open to bypass Gatekeeper"
   - Include screenshots

2. **Homebrew Cask** (users trust Homebrew):
```bash
# Users install via:
brew install --cask windowsnap
```

3. **Build from source**:
```bash
# Users can build themselves:
git clone https://github.com/yourusername/windowsnap
cd windowsnap/WindowSnap
bash scripts/build_bundle.sh
open dist/WindowSnap.app
```

---

## Summary

- **For personal use**: Use workarounds above
- **For small distribution**: Include workaround instructions
- **For professional distribution**: Get Apple Developer account & sign/notarize
- **For open source**: Encourage building from source or Homebrew

The signing/notarization process takes ~15 minutes once set up, and completely eliminates user warnings.

