#!/usr/bin/env bash
set -euo pipefail

# Manual bundle build script for WindowSnap using SwiftPM output.
# Produces: dist/WindowSnap.app and a zip archive.

APP_NAME="WindowSnap"
BUNDLE_ID="com.windowsnap.app"
VERSION="1.0"
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
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
EOF
fi

# Compile asset catalog if actool available
if command -v xcrun >/dev/null && [[ -d "$ASSETS_DIR" ]]; then
  echo "[2/5] Compiling asset catalog..."
  TMP_ASSET_BUILD="$DIST_DIR/_AssetBuild"
  mkdir -p "$TMP_ASSET_BUILD"
  xcrun actool "$ASSETS_DIR" \
    --compile "$RESOURCES_DIR" \
    --platform macosx \
    --minimum-deployment-target 12.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$TMP_ASSET_BUILD/asset.plist" \
    >/dev/null || echo "actool failed (continuing, icon may be missing)"
fi

# Embed basic PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# (Optional) Codesign placeholder
if security find-identity -v -p codesigning >/dev/null 2>&1; then
  echo "[3/5] Attempting ad-hoc codesign (override with CODESIGN_ID if desired)..."
  CODESIGN_ID="${CODESIGN_ID:--}" # '-' means ad-hoc
  codesign --force --sign "$CODESIGN_ID" --timestamp=none "$APP_DIR" || echo "Codesign failed; continuing unsigned."
else
  echo "[3/5] Skipping codesign (no identities)."
fi

# Zip archive
echo "[4/5] Creating archive..."
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

echo "[5/5] Done. Outputs:"
ls -1 "$DIST_DIR" | sed 's/^/  /'
