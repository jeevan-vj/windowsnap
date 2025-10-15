#!/usr/bin/env bash
set -euo pipefail

# Manual bundle build script for WindowSnap using SwiftPM output.
# Produces: dist/WindowSnap.app and a zip archive.

APP_NAME="WindowSnap"
BUNDLE_ID="com.windowsnap.app"
VERSION="1.2.0"
BUILD="$(date +%Y%m%d%H%M%S)"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_SOURCE="$ROOT_DIR/WindowSnap/App/Info.plist"
ASSETS_DIR="$ROOT_DIR/WindowSnap/App/Assets.xcassets"

mkdir -p "$DIST_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

echo "[1/5] Building SwiftPM release binary..."
swift build -c release

BINARY_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"
if [[ ! -f "$BINARY_PATH" ]]; then
  echo "Binary not found at $BINARY_PATH" >&2
  exit 1
fi
cp "$BINARY_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy Info.plist (mutate version/build)
if [[ -f "$PLIST_SOURCE" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST_SOURCE" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST_SOURCE" 2>/dev/null || true
  cp "$PLIST_SOURCE" "$CONTENTS_DIR/Info.plist"
else
  cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>${APP_NAME}</string>
<key>CFBundleDisplayName</key><string>${APP_NAME}</string>
<key>CFBundleExecutable</key><string>${APP_NAME}</string>
<key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>${VERSION}</string>
<key>CFBundleVersion</key><string>${BUILD}</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
EOF
fi

# Generate icons if they don't exist
echo "[2/6] Ensuring icons are available..."
ICON_SET_DIR="$ASSETS_DIR/AppIcon.appiconset"
if [[ ! -f "$ICON_SET_DIR/icon_16x16.png" ]]; then
  echo "   Icons not found, generating..."
  bash "$ROOT_DIR/scripts/generate-icons.sh"
fi

# Compile asset catalog if actool available
if command -v xcrun >/dev/null && [[ -d "$ASSETS_DIR" ]]; then
  echo "[3/6] Compiling asset catalog..."
  TMP_ASSET_BUILD="$DIST_DIR/_AssetBuild"
  mkdir -p "$TMP_ASSET_BUILD"
  
  # Run actool with verbose output to debug issues
  echo "   Running actool..."
  if xcrun actool "$ASSETS_DIR" \
    --compile "$RESOURCES_DIR" \
    --platform macosx \
    --minimum-deployment-target 12.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$TMP_ASSET_BUILD/asset.plist" 2>&1; then
    echo "   ✅ Asset catalog compiled successfully"
    
    # Merge asset plist if it was created
    if [[ -f "$TMP_ASSET_BUILD/asset.plist" ]]; then
      echo "   Merging asset info into main plist..."
      # This would require PlistBuddy commands to merge properly
      # For now, we'll rely on the app-icon parameter above
    fi
  else
    echo "   ⚠️  actool failed - icon may not appear correctly"
    echo "   App will still run but may show default icon"
  fi
  
  # Clean up temporary files
  rm -rf "$TMP_ASSET_BUILD"
else
  echo "[3/6] Skipping asset catalog compilation (actool not available)"
fi

# Embed basic PkgInfo
echo "[4/6] Creating PkgInfo..."
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Code signing
if [[ -n "${CODESIGN_ID:-}" ]]; then
  echo "[5/6] Code signing with identity: $CODESIGN_ID..."
  # Sign with hardened runtime and timestamp server
  codesign --force --sign "$CODESIGN_ID" \
    --options runtime \
    --timestamp \
    --deep \
    "$APP_DIR" || {
      echo "❌ Codesign failed!"
      exit 1
    }
  echo "✅ Code signing successful"
  
  # Verify the signature
  codesign --verify --verbose "$APP_DIR"
else
  echo "[5/6] ⚠️  WARNING: App is not code-signed (set CODESIGN_ID environment variable)"
  echo "   Users will see 'App cannot be verified' warning"
  echo "   For distribution, you need a valid Developer ID certificate"
  # Ad-hoc signing for local testing only
  codesign --force --sign "-" "$APP_DIR" 2>/dev/null || true
fi

# Zip archive
echo "[6/6] Creating archive..."
( cd "$DIST_DIR" && zip -qry "${APP_NAME}.zip" "${APP_NAME}.app" )

# Notarization helper instructions
cat > "$DIST_DIR/NOTARIZATION_STEPS.txt" <<EON
# Notarize (replace TEAM_ID, APPLE_ID, KEYCHAIN_PROFILE accordingly):
# xcrun notarytool submit ${APP_NAME}.zip --apple-id YOUR_APPLE_ID --team-id TEAM_ID --keychain-profile PROFILE --wait
# After success:
# xcrun stapler staple "${APP_NAME}.app"
# Verify:
# spctl -a -v "${APP_NAME}.app"
EON

echo "✅ Build complete! Outputs:"
ls -1 "$DIST_DIR" | sed 's/^/  /'
