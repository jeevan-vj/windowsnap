#!/usr/bin/env bash
set -euo pipefail

# Build ad-hoc distribution for GitHub releases
# This creates a signed, ready-to-distribute package

APP_NAME="WindowSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"

echo "📦 Building Ad-Hoc Distribution for GitHub Release"
echo "=================================================="
echo ""

# Check for signing identities
echo "Checking for signing certificates..."
DEVELOPER_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/' || echo "")
APPLE_DIST=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Distribution" | head -1 | sed 's/.*"\(.*\)".*/\1/' || echo "")
APPLE_DEV=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -1 | sed 's/.*"\(.*\)".*/\1/' || echo "")

# Prefer Developer ID for ad-hoc distribution
if [[ -n "$DEVELOPER_ID" ]]; then
  CODESIGN_ID="$DEVELOPER_ID"
  SIGN_TYPE="Developer ID Application"
  echo "✅ Using: $SIGN_TYPE"
  echo "   $CODESIGN_ID"
elif [[ -n "$APPLE_DIST" ]]; then
  CODESIGN_ID="$APPLE_DIST"
  SIGN_TYPE="Apple Distribution"
  echo "✅ Using: $SIGN_TYPE"
  echo "   $CODESIGN_ID"
elif [[ -n "$APPLE_DEV" ]]; then
  CODESIGN_ID="$APPLE_DEV"
  SIGN_TYPE="Apple Development"
  echo "⚠️  Using: $SIGN_TYPE (for testing only)"
  echo "   $CODESIGN_ID"
  echo ""
  echo "   Note: For proper distribution, create 'Developer ID Application' certificate:"
  echo "   Xcode → Settings → Accounts → Manage Certificates → '+' → 'Developer ID Application'"
else
  echo "❌ No signing certificate found!"
  echo ""
  echo "Please create a certificate:"
  echo "  1. Xcode → Settings → Accounts"
  echo "  2. Select your team → Manage Certificates"
  echo "  3. Click '+' → 'Developer ID Application'"
  exit 1
fi

echo ""

# Export for build script
export CODESIGN_ID

# Build the app bundle
echo "Building app bundle..."
bash "$ROOT_DIR/scripts/build_bundle.sh"

if [[ ! -d "$DIST_DIR/${APP_NAME}.app" ]]; then
  echo "❌ Build failed!"
  exit 1
fi

# Verify signature
echo ""
echo "Verifying signature..."
codesign --verify --verbose "$DIST_DIR/${APP_NAME}.app" || {
  echo "❌ Signature verification failed!"
  exit 1
}

# Get version for release
VERSION=$(cat "$ROOT_DIR/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "1.0.0")
RELEASE_NAME="${APP_NAME}-${VERSION}-macOS"

# Create release directory
RELEASE_DIR="$DIST_DIR/release"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# Copy app
cp -R "$DIST_DIR/${APP_NAME}.app" "$RELEASE_DIR/"

# Create zip for GitHub release
echo ""
echo "Creating release archive..."
cd "$RELEASE_DIR"
zip -qry "${RELEASE_NAME}.zip" "${APP_NAME}.app"
cd "$ROOT_DIR"

# Move zip to dist
mv "$RELEASE_DIR/${RELEASE_NAME}.zip" "$DIST_DIR/"

# Create DMG
echo "Creating DMG..."
bash "$ROOT_DIR/scripts/package_dmg.sh"
DMG_NAME="${APP_NAME}.dmg"
if [[ -f "$DIST_DIR/$DMG_NAME" ]]; then
  # Rename DMG with version
  mv "$DIST_DIR/$DMG_NAME" "$DIST_DIR/${RELEASE_NAME}.dmg"
fi

# Create checksums
echo ""
echo "Creating checksums..."
cd "$DIST_DIR"
if [[ -f "${RELEASE_NAME}.zip" ]]; then
  shasum -a 256 "${RELEASE_NAME}.zip" > "${RELEASE_NAME}.zip.sha256"
fi
if [[ -f "${RELEASE_NAME}.dmg" ]]; then
  shasum -a 256 "${RELEASE_NAME}.dmg" > "${RELEASE_NAME}.dmg.sha256"
fi
cd "$ROOT_DIR"

# Display signature info
echo ""
echo "📋 Release Package Info"
echo "======================="
echo "Version: $VERSION"
echo "Signing: $SIGN_TYPE"
echo ""
codesign -dvv "$DIST_DIR/${APP_NAME}.app" 2>&1 | grep -E "Authority|Identifier|TeamIdentifier" | head -5
echo ""

# List release files
echo "📦 Release Files (ready for GitHub):"
echo "===================================="
ls -lh "$DIST_DIR" | grep -E "${RELEASE_NAME}|${APP_NAME}\.app" | awk '{print "  " $9 " (" $5 ")"}'
echo ""

# Create release notes template
cat > "$DIST_DIR/RELEASE_NOTES_TEMPLATE.md" <<EOF
# WindowSnap $VERSION

## Installation

### Option 1: DMG (Recommended)
1. Download \`${RELEASE_NAME}.dmg\`
2. Open the DMG
3. Drag WindowSnap.app to Applications folder

### Option 2: ZIP
1. Download \`${RELEASE_NAME}.zip\`
2. Extract the ZIP
3. Move WindowSnap.app to Applications folder

## First Launch

On first launch, macOS may show a security warning. To open:
1. Right-click WindowSnap.app
2. Select "Open"
3. Click "Open" in the dialog

Or remove quarantine flag:
\`\`\`bash
xattr -d com.apple.quarantine /Applications/WindowSnap.app
\`\`\`

## Verification

Verify the download:
\`\`\`bash
# For ZIP
shasum -a 256 -c ${RELEASE_NAME}.zip.sha256

# For DMG
shasum -a 256 -c ${RELEASE_NAME}.dmg.sha256
\`\`\`

## Changes

- [Add your release notes here]

## System Requirements

- macOS 12.0 or later
EOF

echo "✅ Ad-hoc distribution ready!"
echo ""
echo "📝 Next steps:"
echo "  1. Review: dist/RELEASE_NOTES_TEMPLATE.md"
echo "  2. Upload to GitHub Release:"
echo "     - ${RELEASE_NAME}.zip"
echo "     - ${RELEASE_NAME}.dmg (optional)"
echo "     - ${RELEASE_NAME}.zip.sha256"
echo "     - ${RELEASE_NAME}.dmg.sha256 (optional)"
echo ""
if [[ "$SIGN_TYPE" == "Apple Development" ]]; then
  echo "⚠️  Note: Using development certificate. For production, create:"
  echo "     Developer ID Application certificate in Xcode"
fi



