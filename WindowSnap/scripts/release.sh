#!/usr/bin/env bash
set -euo pipefail

# WindowSnap Complete Release Script
# Automates: version bump, build, sign, notarize, package, and GitHub release
#
# Usage:
#   bash scripts/release.sh [major|minor|patch] [--skip-bump] [--skip-notarize] [--draft]
#
# Options:
#   major|minor|patch  - Version bump type (default: patch)
#   --skip-bump        - Skip version bumping (use current VERSION file)
#   --skip-notarize    - Skip notarization (faster, but users will see warnings)
#   --draft            - Create GitHub release as draft
#
# Prerequisites:
#   - CODESIGN_ID environment variable set (or will auto-detect)
#   - NOTARY_PROFILE environment variable set (or will use "windowsnap-notary")
#   - GitHub CLI (gh) installed and authenticated
#   - Apple Developer account with notarization setup

APP_NAME="WindowSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"
DIST_DIR="$ROOT_DIR/dist"
VERSION_FILE="$ROOT_DIR/VERSION"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
BUMP_TYPE="patch"
SKIP_BUMP=false
SKIP_NOTARIZE=false
DRAFT_RELEASE=false

for arg in "$@"; do
  case "$arg" in
    major|minor|patch)
      BUMP_TYPE="$arg"
      ;;
    --skip-bump)
      SKIP_BUMP=true
      ;;
    --skip-notarize)
      SKIP_NOTARIZE=true
      ;;
    --draft)
      DRAFT_RELEASE=true
      ;;
    *)
      echo -e "${RED}Unknown option: $arg${NC}" >&2
      echo "Usage: $0 [major|minor|patch] [--skip-bump] [--skip-notarize] [--draft]"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   WindowSnap Complete Release Script${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Check prerequisites
echo -e "${YELLOW}[1/8]${NC} Checking prerequisites..."

# Check for gh CLI
if ! command -v gh &> /dev/null; then
  echo -e "${RED}❌ GitHub CLI (gh) not found${NC}"
  echo "   Install: brew install gh"
  exit 1
fi

# Check gh authentication
if ! gh auth status &> /dev/null; then
  echo -e "${RED}❌ GitHub CLI not authenticated${NC}"
  echo "   Run: gh auth login"
  exit 1
fi

# Auto-detect signing identity if not set
if [[ -z "${CODESIGN_ID:-}" ]]; then
  CODESIGN_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
  if [[ -z "$CODESIGN_ID" ]]; then
    echo -e "${RED}❌ No Developer ID Application certificate found${NC}"
    echo "   Set CODESIGN_ID environment variable or install certificate"
    exit 1
  fi
  echo -e "${GREEN}✓${NC} Auto-detected signing identity: $CODESIGN_ID"
  export CODESIGN_ID
else
  echo -e "${GREEN}✓${NC} Using signing identity: $CODESIGN_ID"
fi

# Auto-detect notary profile if not set
if [[ -z "${NOTARY_PROFILE:-}" ]]; then
  NOTARY_PROFILE="windowsnap-notary"
  echo -e "${GREEN}✓${NC} Using notary profile: $NOTARY_PROFILE"
  export NOTARY_PROFILE
else
  echo -e "${GREEN}✓${NC} Using notary profile: $NOTARY_PROFILE"
fi

echo ""

# Step 2: Determine version
echo -e "${YELLOW}[2/8]${NC} Determining version..."

if [[ "$SKIP_BUMP" == "true" ]]; then
  VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
  echo -e "${GREEN}✓${NC} Using existing version: $VERSION"
else
  # Get latest GitHub release version
  LATEST_RELEASE=$(gh release list --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null || echo "")
  
  if [[ -n "$LATEST_RELEASE" ]]; then
    # Extract version number (remove 'v' prefix)
    LATEST_VERSION="${LATEST_RELEASE#v}"
    echo -e "${BLUE}Latest GitHub release: $LATEST_RELEASE${NC}"
  else
    LATEST_VERSION=""
    echo -e "${YELLOW}No previous releases found${NC}"
  fi
  
  # Get current VERSION file
  CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]' || echo "0.0.0")
  
  # Determine base version: use latest GitHub release if it's higher, otherwise use VERSION file
  if [[ -n "$LATEST_VERSION" ]]; then
    # Compare versions - use the higher one
    if [[ "$(printf '%s\n' "$LATEST_VERSION" "$CURRENT_VERSION" | sort -V | tail -1)" == "$LATEST_VERSION" ]]; then
      BASE_VERSION="$LATEST_VERSION"
      # Update VERSION file to match latest release before bumping
      echo "$BASE_VERSION" > "$VERSION_FILE"
      /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $BASE_VERSION" "$ROOT_DIR/WindowSnap/App/Info.plist" 2>/dev/null || true
      echo -e "${BLUE}Updated VERSION file to match latest release: $BASE_VERSION${NC}"
    else
      BASE_VERSION="$CURRENT_VERSION"
    fi
  else
    BASE_VERSION="$CURRENT_VERSION"
  fi
  
  # Bump version
  echo -e "${BLUE}Bumping $BUMP_TYPE version from $BASE_VERSION...${NC}"
  bash "$SCRIPTS_DIR/bump-version.sh" "$BUMP_TYPE" > /dev/null
  
  # Read the new version
  VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
  echo -e "${GREEN}✓${NC} Version bumped to: $VERSION"
fi

VERSION_TAG="v$VERSION"
echo ""

# Step 3: Build universal bundle
echo -e "${YELLOW}[3/8]${NC} Building universal app bundle..."
if bash "$SCRIPTS_DIR/build-universal-bundle.sh"; then
  echo -e "${GREEN}✓${NC} Build successful"
else
  echo -e "${RED}❌ Build failed${NC}"
  exit 1
fi
echo ""

# Step 4: Sign and notarize
if [[ "$SKIP_NOTARIZE" == "true" ]]; then
  echo -e "${YELLOW}[4/8]${NC} Skipping notarization (--skip-notarize)"
  echo -e "${YELLOW}⚠${NC}  Users will see security warnings"
else
  echo -e "${YELLOW}[4/8]${NC} Signing and notarizing app..."
  if bash "$SCRIPTS_DIR/sign-and-notarize.sh"; then
    echo -e "${GREEN}✓${NC} Signing and notarization successful"
  else
    echo -e "${RED}❌ Signing/notarization failed${NC}"
    exit 1
  fi
fi
echo ""

# Step 5: Create DMG
echo -e "${YELLOW}[5/8]${NC} Creating DMG package..."

# Clean up any mounted volumes
hdiutil detach /Volumes/WindowSnap 2>/dev/null || true
hdiutil detach "/Volumes/WindowSnap 1" 2>/dev/null || true
hdiutil detach "/Volumes/WindowSnap 2" 2>/dev/null || true
hdiutil detach "/Volumes/WindowSnap 3" 2>/dev/null || true

# Clean up old DMG files
rm -rf "$DIST_DIR/dmg_src" "$DIST_DIR/WindowSnap-rw.dmg" "$DIST_DIR/${APP_NAME}-${VERSION}-macOS-notarized.dmg"

# Create DMG source directory
mkdir -p "$DIST_DIR/dmg_src"
cp -R "$DIST_DIR/${APP_NAME}.app" "$DIST_DIR/dmg_src/"
ln -s /Applications "$DIST_DIR/dmg_src/Applications"

# Create DMG
DMG_NAME="${APP_NAME}-${VERSION}-macOS-notarized.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

if hdiutil create -ov -srcfolder "$DIST_DIR/dmg_src" \
  -volname "$APP_NAME" \
  -fs HFS+ \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH" 2>&1; then
  echo -e "${GREEN}✓${NC} DMG created: $DMG_NAME"
else
  echo -e "${RED}❌ DMG creation failed${NC}"
  exit 1
fi

# Sign DMG
echo "   Signing DMG..."
if codesign --force --sign "$CODESIGN_ID" --timestamp "$DMG_PATH"; then
  codesign --verify --verbose "$DMG_PATH" > /dev/null
  echo -e "${GREEN}✓${NC} DMG signed"
else
  echo -e "${RED}❌ DMG signing failed${NC}"
  exit 1
fi

# Clean up
rm -rf "$DIST_DIR/dmg_src"
echo ""

# Step 6: Prepare ZIP file
echo -e "${YELLOW}[6/8]${NC} Preparing distribution files..."
ZIP_NAME="${APP_NAME}-${VERSION}-macOS-notarized.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

# Copy existing zip (already contains notarized app)
if [[ -f "$DIST_DIR/${APP_NAME}.zip" ]]; then
  cp "$DIST_DIR/${APP_NAME}.zip" "$ZIP_PATH"
  echo -e "${GREEN}✓${NC} ZIP file ready: $ZIP_NAME"
else
  echo -e "${RED}❌ ZIP file not found${NC}"
  exit 1
fi
echo ""

# Step 7: Generate release notes
echo -e "${YELLOW}[7/8]${NC} Generating release notes..."

# Get commits since last release (re-fetch if we skipped bump)
if [[ "$SKIP_BUMP" == "true" ]]; then
  LATEST_RELEASE=$(gh release list --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null || echo "")
fi

# Get commits since last release
if [[ -n "${LATEST_RELEASE:-}" ]]; then
  COMMITS=$(git log "${LATEST_RELEASE}..HEAD" --oneline --no-merges 2>/dev/null | head -10 || echo "")
else
  COMMITS=$(git log --oneline --no-merges -10 2>/dev/null || echo "")
fi

# Build release notes
RELEASE_NOTES="## What's New

"

if [[ -n "$COMMITS" ]]; then
  RELEASE_NOTES+="### Changes since ${LATEST_RELEASE:-last release}:

"
  while IFS= read -r commit; do
    if [[ -n "$commit" ]]; then
      # Extract commit message (skip hash)
      MSG=$(echo "$commit" | sed 's/^[a-f0-9]* //')
      RELEASE_NOTES+="- $MSG
"
    fi
  done <<< "$COMMITS"
  RELEASE_NOTES+="
"
else
  RELEASE_NOTES+="- Version bump to $VERSION
- Build improvements and bug fixes

"
fi

RELEASE_NOTES+="## Downloads

- **${DMG_NAME}** - Disk image for easy installation (recommended)
- **${ZIP_NAME}** - Zip archive

Both packages include:
- ✅ Universal binaries supporting Apple Silicon (M1/M2/M3/M4) and Intel Macs
- ✅ Code signed with Developer ID
"

if [[ "$SKIP_NOTARIZE" != "true" ]]; then
  RELEASE_NOTES+="- ✅ Notarized by Apple (no Gatekeeper warnings)
"
else
  RELEASE_NOTES+="- ⚠️  Not notarized (users may see security warnings)
"
fi

RELEASE_NOTES+="- ✅ macOS 12.0 (Monterey) or later

## Installation

1. Download the DMG file
2. Double-click to mount
3. Drag ${APP_NAME}.app to Applications folder
4. Launch from Applications or Spotlight

The app will request Accessibility permissions on first run - this is required for window management features."

RELEASE_TITLE="v${VERSION} - Release"

echo -e "${GREEN}✓${NC} Release notes generated"
echo ""

# Step 8: Create GitHub release
echo -e "${YELLOW}[8/8]${NC} Creating GitHub release..."

DRAFT_FLAG=""
if [[ "$DRAFT_RELEASE" == "true" ]]; then
  DRAFT_FLAG="--draft"
  echo -e "${BLUE}Creating as draft release...${NC}"
fi

if gh release create "$VERSION_TAG" \
  --title "$RELEASE_TITLE" \
  --notes "$RELEASE_NOTES" \
  $DRAFT_FLAG \
  "$DMG_PATH" \
  "$ZIP_PATH" 2>&1; then
  echo -e "${GREEN}✓${NC} GitHub release created: $VERSION_TAG"
  RELEASE_URL=$(gh release view "$VERSION_TAG" --json url --jq '.url')
  echo -e "${GREEN}Release URL: $RELEASE_URL${NC}"
else
  echo -e "${RED}❌ GitHub release creation failed${NC}"
  exit 1
fi
echo ""

# Success summary
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Release Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Release Information:${NC}"
echo -e "  Version:        ${YELLOW}$VERSION${NC}"
echo -e "  Tag:            ${YELLOW}$VERSION_TAG${NC}"
echo -e "  DMG:            ${GREEN}$DMG_NAME${NC}"
echo -e "  ZIP:            ${GREEN}$ZIP_NAME${NC}"
echo ""
echo -e "${BLUE}Distribution Files:${NC}"
ls -lh "$DMG_PATH" "$ZIP_PATH" | awk '{print "  " $9 " (" $5 ")"}'
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo -e "  1. Review the release: ${YELLOW}$RELEASE_URL${NC}"
if [[ "$DRAFT_RELEASE" == "true" ]]; then
  echo -e "  2. Publish the draft when ready: ${YELLOW}gh release edit $VERSION_TAG --draft=false${NC}"
fi
echo -e "  2. Commit version changes: ${YELLOW}git add $VERSION_FILE WindowSnap/App/Info.plist${NC}"
echo -e "  3. Commit and push: ${YELLOW}git commit -m \"Release $VERSION_TAG\" && git push${NC}"
echo ""

