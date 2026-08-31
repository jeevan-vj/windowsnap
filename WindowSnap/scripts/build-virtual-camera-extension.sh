#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXTENSION_NAME="WindowSnapVirtualCameraExtension"
EXTENSION_ID="com.jeevanwijerathna.windowsnap.VirtualCameraExtension"
SOURCE_DIR="$ROOT_DIR/$EXTENSION_NAME"
BUILD_DIR="$ROOT_DIR/.build/virtual-camera-extension"
BUNDLE_DIR="$BUILD_DIR/$EXTENSION_NAME.systemextension"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
ENTITLEMENTS="$SOURCE_DIR/$EXTENSION_NAME.entitlements"
ARM64_BINARY="$BUILD_DIR/$EXTENSION_NAME-arm64"
X86_64_BINARY="$BUILD_DIR/$EXTENSION_NAME-x86_64"
UNIVERSAL_BINARY="$MACOS_DIR/$EXTENSION_NAME"

rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"

build_architecture() {
  local architecture="$1"
  local output="$2"
  swiftc \
    -O \
    -target "$architecture-apple-macos13.0" \
    "$SOURCE_DIR/main.swift" \
    "$SOURCE_DIR/WindowSnapVirtualCameraProvider.swift" \
    -framework CoreMediaIO \
    -framework CoreMedia \
    -framework CoreVideo \
    -o "$output"
}

build_architecture arm64 "$ARM64_BINARY"
build_architecture x86_64 "$X86_64_BINARY"
lipo -create "$ARM64_BINARY" "$X86_64_BINARY" -output "$UNIVERSAL_BINARY"
chmod +x "$UNIVERSAL_BINARY"
lipo "$UNIVERSAL_BINARY" -verify_arch arm64 x86_64

cp "$SOURCE_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $EXTENSION_ID" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $EXTENSION_NAME" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true

if [[ -n "${CODESIGN_ID:-}" ]]; then
  codesign --force --sign "$CODESIGN_ID" --entitlements "$ENTITLEMENTS" "$BUNDLE_DIR"
else
  codesign --force --sign "-" --entitlements "$ENTITLEMENTS" "$BUNDLE_DIR" 2>/dev/null || true
fi

echo "$BUNDLE_DIR"
