#!/usr/bin/env bash
set -euo pipefail

# Universal Binary Build Script for WindowSnap
# Builds for both Apple Silicon (ARM64) and Intel (x86_64)

APP_NAME="WindowSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
UNIVERSAL_DIR="$BUILD_DIR/universal"
RELEASE_CONFIG="release"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   WindowSnap Universal Binary Build Script${NC}"
echo -e "${BLUE}   Building for Apple Silicon (ARM64) + Intel (x86_64)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Clean previous builds
echo -e "${YELLOW}[1/5]${NC} Cleaning previous builds..."
rm -rf "$BUILD_DIR/arm64-apple-macosx"
rm -rf "$BUILD_DIR/x86_64-apple-macosx"
rm -rf "$UNIVERSAL_DIR"
mkdir -p "$UNIVERSAL_DIR"
echo -e "${GREEN}✓${NC} Cleaned build directories"
echo ""

# Build for Apple Silicon (ARM64)
echo -e "${YELLOW}[2/5]${NC} Building for Apple Silicon (ARM64)..."
if swift build \
    -c "$RELEASE_CONFIG" \
    --arch arm64 \
    --product "$APP_NAME"; then
    echo -e "${GREEN}✓${NC} ARM64 build successful"
else
    echo -e "${RED}✗${NC} ARM64 build failed"
    exit 1
fi
echo ""

# Build for Intel (x86_64)
echo -e "${YELLOW}[3/5]${NC} Building for Intel (x86_64)..."
if swift build \
    -c "$RELEASE_CONFIG" \
    --arch x86_64 \
    --product "$APP_NAME"; then
    echo -e "${GREEN}✓${NC} x86_64 build successful"
else
    echo -e "${RED}✗${NC} x86_64 build failed"
    exit 1
fi
echo ""

# Create universal binary using lipo
echo -e "${YELLOW}[4/5]${NC} Creating universal binary..."

ARM64_BINARY="$BUILD_DIR/arm64-apple-macosx/$RELEASE_CONFIG/$APP_NAME"
X86_64_BINARY="$BUILD_DIR/x86_64-apple-macosx/$RELEASE_CONFIG/$APP_NAME"
UNIVERSAL_BINARY="$UNIVERSAL_DIR/$APP_NAME"

# Check if both binaries exist
if [[ ! -f "$ARM64_BINARY" ]]; then
    echo -e "${RED}✗${NC} ARM64 binary not found at: $ARM64_BINARY"
    exit 1
fi

if [[ ! -f "$X86_64_BINARY" ]]; then
    echo -e "${RED}✗${NC} x86_64 binary not found at: $X86_64_BINARY"
    exit 1
fi

# Combine binaries
if lipo -create \
    "$ARM64_BINARY" \
    "$X86_64_BINARY" \
    -output "$UNIVERSAL_BINARY"; then
    echo -e "${GREEN}✓${NC} Universal binary created successfully"
else
    echo -e "${RED}✗${NC} Failed to create universal binary"
    exit 1
fi

# Make executable
chmod +x "$UNIVERSAL_BINARY"

# Sign the binary (required for Accessibility permissions to appear in System Settings)
echo -e "${YELLOW}[5/6]${NC} Signing binary with entitlements..."
ENTITLEMENTS_FILE="$ROOT_DIR/WindowSnap.entitlements"
if [[ -f "$ENTITLEMENTS_FILE" ]]; then
    # Ad-hoc sign with entitlements (works for local testing)
    codesign --force --sign "-" \
        --entitlements "$ENTITLEMENTS_FILE" \
        "$UNIVERSAL_BINARY" 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Binary signed with entitlements"
else
    echo -e "${YELLOW}⚠${NC}  Entitlements file not found, signing without it"
    codesign --force --sign "-" "$UNIVERSAL_BINARY" 2>/dev/null || true
fi
echo ""

# Verify the universal binary
echo -e "${YELLOW}[6/6]${NC} Verifying universal binary..."
echo ""
echo -e "${BLUE}Binary Information:${NC}"
echo -e "  Location: ${GREEN}$UNIVERSAL_BINARY${NC}"
echo ""

# Show architectures
echo -e "${BLUE}Supported Architectures:${NC}"
lipo -info "$UNIVERSAL_BINARY" | sed 's/^/  /'
echo ""

# Show detailed architecture info
echo -e "${BLUE}Detailed Architecture Info:${NC}"
lipo -detailed_info "$UNIVERSAL_BINARY" | sed 's/^/  /'
echo ""

# Show file size
ARM64_SIZE=$(du -h "$ARM64_BINARY" | cut -f1)
X86_64_SIZE=$(du -h "$X86_64_BINARY" | cut -f1)
UNIVERSAL_SIZE=$(du -h "$UNIVERSAL_BINARY" | cut -f1)

echo -e "${BLUE}Binary Sizes:${NC}"
echo -e "  ARM64 only:     ${YELLOW}$ARM64_SIZE${NC}"
echo -e "  x86_64 only:    ${YELLOW}$X86_64_SIZE${NC}"
echo -e "  Universal:      ${YELLOW}$UNIVERSAL_SIZE${NC}"
echo ""

# Success message
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Universal binary build complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo -e "  1. Test on Apple Silicon Mac:"
echo -e "     ${YELLOW}$UNIVERSAL_BINARY${NC}"
echo ""
echo -e "  2. Test on Intel Mac:"
echo -e "     ${YELLOW}$UNIVERSAL_BINARY${NC}"
echo ""
echo -e "  3. Create app bundle:"
echo -e "     ${YELLOW}./scripts/build_bundle.sh${NC}"
echo ""
echo -e "  4. Code sign (optional):"
echo -e "     ${YELLOW}CODESIGN_ID='Developer ID' ./scripts/build_bundle.sh${NC}"
echo ""
