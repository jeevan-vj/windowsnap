#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXTENSION_NAME="WindowSnapVirtualCameraExtension"
EXTENSION_ID="${WINDOWSNAP_VIRTUAL_CAMERA_ID:-com.jeevanwijerathna.windowsnap.VirtualCameraExtension}"
PRODUCT_NAME="$EXTENSION_ID"
DEVELOPMENT_APP_GROUP_ID="${WINDOWSNAP_DEVELOPMENT_APP_GROUP_ID:-group.com.jeevanwijerathna.windowsnap}"
SOURCE_DIR="$ROOT_DIR/$EXTENSION_NAME"
BUILD_DIR="$ROOT_DIR/.build/virtual-camera-extension"
BUNDLE_DIR="$BUILD_DIR/$PRODUCT_NAME.systemextension"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
ENTITLEMENTS="$BUILD_DIR/$EXTENSION_NAME.entitlements"
HOST_ENTITLEMENTS="$BUILD_DIR/WindowSnapVirtualCameraHost.entitlements"
ARM64_BINARY="$BUILD_DIR/$EXTENSION_NAME-arm64"
X86_64_BINARY="$BUILD_DIR/$EXTENSION_NAME-x86_64"
UNIVERSAL_BINARY="$MACOS_DIR/$EXTENSION_NAME"

if [[ -n "${CODESIGN_ID:-}" && -z "${TEAM_ID:-}" ]]; then
  echo "error: TEAM_ID is required when CODESIGN_ID is set for a signed camera extension build" >&2
  exit 1
fi

if [[ -n "${TEAM_ID:-}" ]]; then
  APP_GROUP_ID="$TEAM_ID.$EXTENSION_ID"
  MACH_SERVICE_NAME="$TEAM_ID.$EXTENSION_ID"
else
  APP_GROUP_ID="$DEVELOPMENT_APP_GROUP_ID"
  MACH_SERVICE_NAME="$EXTENSION_ID"
fi

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
    -framework CoreImage \
    -framework IOSurface \
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
/usr/libexec/PlistBuddy -c "Set :CFBundleName $PRODUCT_NAME" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CMIOExtensionMachServiceName $MACH_SERVICE_NAME" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :WindowSnapCameraAppGroupIdentifier string $APP_GROUP_ID" "$CONTENTS_DIR/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :WindowSnapCameraAppGroupIdentifier $APP_GROUP_ID" "$CONTENTS_DIR/Info.plist"

cp "$SOURCE_DIR/$EXTENSION_NAME.entitlements" "$ENTITLEMENTS"
/usr/libexec/PlistBuddy -c "Set :com.apple.security.application-groups:0 $APP_GROUP_ID" "$ENTITLEMENTS"

cp "$ROOT_DIR/WindowSnapVirtualCameraHost.entitlements" "$HOST_ENTITLEMENTS"
/usr/libexec/PlistBuddy -c "Set :com.apple.security.application-groups:0 $APP_GROUP_ID" "$HOST_ENTITLEMENTS"

if [[ -n "${CODESIGN_ID:-}" ]]; then
  codesign --force --sign "$CODESIGN_ID" --entitlements "$ENTITLEMENTS" "$BUNDLE_DIR"
else
  codesign --force --sign "-" --entitlements "$ENTITLEMENTS" "$BUNDLE_DIR" 2>/dev/null || true
fi

echo "$BUNDLE_DIR"
