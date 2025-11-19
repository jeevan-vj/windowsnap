#!/usr/bin/env bash
set -euo pipefail

# Create signed and notarized DMG for distribution

APP_NAME="WindowSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/${APP_NAME}.app"
DMG_TMP_DIR="$DIST_DIR/dmg_src"
VERSION=$(cat "$ROOT_DIR/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "1.0.0")
DMG_NAME="${APP_NAME}-${VERSION}-macOS-notarized.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ App bundle not found at $APP_PATH"
  echo "   Run: bash scripts/build_bundle.sh first"
  exit 1
fi

if [[ -z "${CODESIGN_ID:-}" ]]; then
  echo "❌ CODESIGN_ID not set"
  echo "   export CODESIGN_ID=\"Developer ID Application: Your Name (TEAMID)\""
  exit 1
fi

echo "📦 Creating Signed DMG"
echo "======================"
echo "App: $APP_PATH"
echo "DMG: $DMG_PATH"
echo ""

# Clean up
rm -rf "$DMG_TMP_DIR" "$DMG_PATH" "$DIST_DIR/${APP_NAME}-rw.dmg"
mkdir -p "$DMG_TMP_DIR"

# Copy app
echo "[1/6] Copying app to DMG source..."
cp -R "$APP_PATH" "$DMG_TMP_DIR/"

# Create Applications symlink
echo "[2/6] Creating Applications symlink..."
ln -s /Applications "$DMG_TMP_DIR/Applications"

# Create read-write DMG
echo "[3/6] Creating DMG..."
hdiutil create -quiet -ov -srcfolder "$DMG_TMP_DIR" \
  -volname "$APP_NAME" \
  -fs HFS+ \
  -format UDRW \
  "$DIST_DIR/${APP_NAME}-rw.dmg"

RW_DMG="$DIST_DIR/${APP_NAME}-rw.dmg"

# Mount and configure (optional: set icon positions)
MOUNT_DIR=$(hdiutil attach "$RW_DMG" -nobrowse -quiet | awk 'END{print $3}')
echo "   Mounted at: $MOUNT_DIR"

# Detach
hdiutil detach "$MOUNT_DIR" -quiet

# Convert to compressed read-only DMG
echo "[4/6] Converting to compressed DMG..."
hdiutil convert "$RW_DMG" -quiet -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
rm -f "$RW_DMG"

# Sign DMG
echo "[5/6] Signing DMG with $CODESIGN_ID..."
codesign --force --sign "$CODESIGN_ID" \
  --timestamp \
  "$DMG_PATH" || {
  echo "❌ DMG signing failed!"
  exit 1
}

# Verify signature
codesign --verify --verbose "$DMG_PATH" || {
  echo "❌ DMG signature verification failed!"
  exit 1
}

echo "✅ DMG created and signed: $DMG_PATH"
echo ""

# Notarize DMG if NOTARY_PROFILE is set
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "[6/6] Notarizing DMG..."
  echo "   This may take several minutes..."
  
  NOTARY_OUTPUT=$(xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait 2>&1)
  
  echo "$NOTARY_OUTPUT"
  
  if echo "$NOTARY_OUTPUT" | grep -q "status: Accepted"; then
    echo "✅ DMG notarization successful!"
    
    # Staple
    echo "   Stapling notarization ticket..."
    xcrun stapler staple "$DMG_PATH" || {
      echo "⚠️  Stapling failed (continuing)"
    }
    
    # Verify
    spctl -a -vv "$DMG_PATH" || {
      echo "⚠️  spctl verification had warnings"
    }
    
    echo ""
    echo "🎉 DMG is signed and notarized!"
  else
    echo ""
    echo "❌ DMG notarization failed!"
    echo "   DMG is still signed but not notarized"
  fi
else
  echo "[6/6] Skipping notarization (NOTARY_PROFILE not set)"
  echo "   DMG is signed but not notarized"
fi

echo ""
echo "📦 DMG ready: $DMG_PATH"
ls -lh "$DMG_PATH"

