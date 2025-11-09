#!/usr/bin/env bash
set -euo pipefail

# Universal App Bundle Build Script for WindowSnap
# Creates a complete .app bundle with universal binary (ARM64 + x86_64)

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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   WindowSnap Universal App Bundle Builder${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Prepare directories
echo -e "${YELLOW}[1/7]${NC} Preparing directories..."
mkdir -p "$DIST_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
echo -e "${GREEN}✓${NC} Directories ready"
echo ""

# Build universal binary
echo -e "${YELLOW}[2/7]${NC} Building universal binary..."
if "$ROOT_DIR/scripts/build-universal.sh"; then
    echo -e "${GREEN}✓${NC} Universal binary built successfully"
else
    echo -e "${RED}✗${NC} Universal binary build failed"
    exit 1
fi
echo ""

# Copy universal binary to app bundle
echo -e "${YELLOW}[3/7]${NC} Copying binary to app bundle..."
UNIVERSAL_BINARY="$ROOT_DIR/.build/universal/$APP_NAME"
if [[ ! -f "$UNIVERSAL_BINARY" ]]; then
  echo -e "${RED}✗${NC} Universal binary not found at $UNIVERSAL_BINARY"
  exit 1
fi

cp "$UNIVERSAL_BINARY" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
echo -e "${GREEN}✓${NC} Binary copied"
echo ""

# Create Info.plist
echo -e "${YELLOW}[4/7]${NC} Creating Info.plist..."
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
echo -e "${GREEN}✓${NC} Info.plist created"
echo ""

# Generate icons if needed
echo -e "${YELLOW}[5/7]${NC} Processing app icon..."
ICON_SET_DIR="$ASSETS_DIR/AppIcon.appiconset"
if [[ ! -f "$ICON_SET_DIR/icon_16x16.png" ]]; then
  echo "   Icons not found, generating..."
  bash "$ROOT_DIR/scripts/generate-icons.sh"
fi

# Compile asset catalog
if command -v xcrun >/dev/null && [[ -d "$ASSETS_DIR" ]]; then
  TMP_ASSET_BUILD="$DIST_DIR/_AssetBuild"
  mkdir -p "$TMP_ASSET_BUILD"

  if xcrun actool "$ASSETS_DIR" \
    --compile "$RESOURCES_DIR" \
    --platform macosx \
    --minimum-deployment-target 12.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$TMP_ASSET_BUILD/asset.plist" 2>&1; then
    echo -e "${GREEN}✓${NC} Asset catalog compiled"
  else
    echo -e "${YELLOW}⚠${NC}  Asset compilation warning (app will still work)"
  fi
  rm -rf "$TMP_ASSET_BUILD"
else
  echo -e "${YELLOW}⚠${NC}  Skipping asset compilation (actool not available)"
fi
echo ""

# Create PkgInfo
echo -e "${YELLOW}[6/7]${NC} Creating PkgInfo..."
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"
echo -e "${GREEN}✓${NC} PkgInfo created"
echo ""

# Code signing
echo -e "${YELLOW}[7/7]${NC} Code signing..."
ENTITLEMENTS_FILE="$ROOT_DIR/WindowSnap.entitlements"
if [[ -n "${CODESIGN_ID:-}" ]]; then
  echo "   Signing with identity: $CODESIGN_ID"
  SIGN_ARGS=(
    --force
    --sign "$CODESIGN_ID"
    --options runtime
    --timestamp
    --deep
  )
  if [[ -f "$ENTITLEMENTS_FILE" ]]; then
    SIGN_ARGS+=(--entitlements "$ENTITLEMENTS_FILE")
  fi
  SIGN_ARGS+=("$APP_DIR")
  
  if codesign "${SIGN_ARGS[@]}"; then
    echo -e "${GREEN}✓${NC} Code signing successful"

    # Verify signature
    codesign --verify --verbose "$APP_DIR"

    # Show signature info
    echo ""
    echo -e "${BLUE}Signature Details:${NC}"
    codesign -dvvv "$APP_DIR" 2>&1 | grep -E "Authority|Identifier|TeamIdentifier|Executable" | sed 's/^/  /'
  else
    echo -e "${RED}✗${NC} Code signing failed"
    exit 1
  fi
else
  echo -e "${YELLOW}⚠${NC}  WARNING: App is not code-signed (set CODESIGN_ID environment variable)"
  echo "   For local testing only - ad-hoc signing"
  SIGN_ARGS=(--force --sign "-")
  if [[ -f "$ENTITLEMENTS_FILE" ]]; then
    SIGN_ARGS+=(--entitlements "$ENTITLEMENTS_FILE")
    echo "   Using entitlements file for accessibility permissions"
  fi
  SIGN_ARGS+=("$APP_DIR")
  codesign "${SIGN_ARGS[@]}" 2>/dev/null || true
  echo -e "${GREEN}✓${NC} Ad-hoc signed for local testing"
fi
echo ""

# Verify architectures in final app
echo -e "${BLUE}Final App Architecture:${NC}"
lipo -info "$MACOS_DIR/$APP_NAME" | sed 's/^/  /'
echo ""

# Create zip archive
echo "Creating distribution archive..."
( cd "$DIST_DIR" && zip -qry "${APP_NAME}.zip" "${APP_NAME}.app" )
echo -e "${GREEN}✓${NC} Archive created: ${APP_NAME}.zip"
echo ""

# Success summary
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Universal app bundle build complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Build Information:${NC}"
echo -e "  Version:        ${YELLOW}$VERSION${NC}"
echo -e "  Build:          ${YELLOW}$BUILD${NC}"
echo -e "  App Bundle:     ${GREEN}$APP_DIR${NC}"
echo -e "  Archive:        ${GREEN}$DIST_DIR/${APP_NAME}.zip${NC}"
echo ""
echo -e "${BLUE}Supported Systems:${NC}"
echo -e "  ${GREEN}✓${NC} macOS 12.0 (Monterey) or later"
echo -e "  ${GREEN}✓${NC} Apple Silicon (M1/M2/M3/M4)"
echo -e "  ${GREEN}✓${NC} Intel (x86_64)"
echo ""
echo -e "${BLUE}Distribution Files:${NC}"
ls -lh "$DIST_DIR" | grep -E "WindowSnap\.(app|zip)" | sed 's/^/  /'
echo ""

if [[ -z "${CODESIGN_ID:-}" ]]; then
  echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}⚠  DISTRIBUTION WARNING${NC}"
  echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "This build is ${RED}NOT signed or notarized${NC} for distribution."
  echo ""
  echo -e "${BLUE}For distribution, you need to:${NC}"
  echo ""
  echo -e "1. Code sign with Developer ID:"
  echo -e "   ${YELLOW}CODESIGN_ID='Developer ID Application: Your Name (TEAM_ID)' ./scripts/build-universal-bundle.sh${NC}"
  echo ""
  echo -e "2. Notarize with Apple:"
  echo -e "   ${YELLOW}xcrun notarytool submit dist/WindowSnap.zip \\${NC}"
  echo -e "   ${YELLOW}  --apple-id YOUR_APPLE_ID \\${NC}"
  echo -e "   ${YELLOW}  --team-id TEAM_ID \\${NC}"
  echo -e "   ${YELLOW}  --keychain-profile PROFILE \\${NC}"
  echo -e "   ${YELLOW}  --wait${NC}"
  echo ""
  echo -e "3. Staple the notarization:"
  echo -e "   ${YELLOW}xcrun stapler staple dist/WindowSnap.app${NC}"
  echo ""
  echo -e "4. Verify:"
  echo -e "   ${YELLOW}spctl -a -v dist/WindowSnap.app${NC}"
  echo ""
fi

echo -e "${BLUE}Testing:${NC}"
echo -e "  Test on this Mac:"
echo -e "    ${YELLOW}open $APP_DIR${NC}"
echo ""
echo -e "  Run from command line:"
echo -e "    ${YELLOW}$MACOS_DIR/$APP_NAME${NC}"
echo ""
