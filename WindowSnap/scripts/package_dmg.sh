#!/usr/bin/env bash
set -euo pipefail

APP_NAME="WindowSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/${APP_NAME}.app"
DMG_TMP_DIR="$DIST_DIR/dmg_src"
DMG_NAME="${APP_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"
DMG_PATH="$DIST_DIR/$DMG_NAME"
BACKGROUND_IMG="" # Optional: set to path of background PNG (512x384 etc.)

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at $APP_PATH. Run build_bundle.sh first." >&2
  exit 1
fi

rm -rf "$DMG_TMP_DIR" "$DMG_PATH"
mkdir -p "$DMG_TMP_DIR"

# Copy app
cp -R "$APP_PATH" "$DMG_TMP_DIR/"

# Create Applications symlink for drag-install UX
ln -s /Applications "$DMG_TMP_DIR/Applications"

# Create initial DMG (read-write for layout tweaks)
hdiutil create -quiet -ov -srcfolder "$DMG_TMP_DIR" -volname "$VOLUME_NAME" -fs HFS+ -format UDRW "$DIST_DIR/${APP_NAME}-rw.dmg"
RW_DMG="$DIST_DIR/${APP_NAME}-rw.dmg"

# Mount
MOUNT_DIR=$(hdiutil attach "$RW_DMG" -nobrowse -quiet | awk 'END{print $3}')

# Optional: set custom icon positions & background using AppleScript / .DS_Store crafting.
# Minimal implementation skips fancy layout.

# Detach
hdiutil detach "$MOUNT_DIR" -quiet

# Convert to compressed read-only DMG
hdiutil convert "$RW_DMG" -quiet -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
rm -f "$RW_DMG"

# Codesign DMG (optional, often you just sign the app and notarize DMG)
if security find-identity -v -p codesigning >/dev/null 2>&1; then
  if [[ -n "${CODESIGN_ID:-}" ]]; then
    echo "Signing DMG with $CODESIGN_ID"
    codesign --force --sign "$CODESIGN_ID" "$DMG_PATH" || echo "DMG signing failed (continuing)."
  fi
fi

echo "Created DMG: $DMG_PATH"

cat > "$DIST_DIR/NOTARIZE_DMG_STEPS.txt" <<EON
# Notarize DMG (after ensuring app inside is already signed & hardened runtime):
# xcrun notarytool submit ${DMG_NAME} --apple-id YOUR_APPLE_ID --team-id TEAMID --keychain-profile NOTARY_PROFILE --wait
# xcrun stapler staple ${DMG_NAME}
# spctl -a -v ${DMG_NAME}
EON

echo "Wrote notarization helper: $DIST_DIR/NOTARIZE_DMG_STEPS.txt"
ls -lh "$DMG_PATH"
