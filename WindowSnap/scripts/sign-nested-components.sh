#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

APP_PATH="${1:-}"
CODESIGN_ID="${2:-}"
ENTITLEMENTS_FILE="${3:-}"
VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS="${4:-}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GENERATED_VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS="$ROOT_DIR/.build/virtual-camera-extension/WindowSnapVirtualCameraExtension.entitlements"
SOURCE_VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS="$ROOT_DIR/WindowSnapVirtualCameraExtension/WindowSnapVirtualCameraExtension.entitlements"

[[ -d "$APP_PATH" ]] || die "App bundle not found: $APP_PATH"
[[ -n "$CODESIGN_ID" ]] || die "A Developer ID Application identity or fingerprint is required"

if [[ "${WINDOWSNAP_LOCAL_SIGNING:-0}" == "1" ]] && \
   ! "$ROOT_DIR/scripts/resolve-developer-id.sh" "$CODESIGN_ID" >/dev/null 2>&1; then
  # Local/dev builds (set by build-universal-bundle.sh when it picked the
  # identity itself) may also use an installed Apple Development identity.
  # Release scripts never set WINDOWSNAP_LOCAL_SIGNING and stay Developer ID only.
  /usr/bin/security find-identity -v -p codesigning 2>/dev/null | grep -F -- "$CODESIGN_ID" | grep -q 'Apple Development:' || \
    die "Local signing identity is neither Developer ID Application nor an installed Apple Development identity"
  echo "Local build: signing with Apple Development identity $CODESIGN_ID"
else
  CODESIGN_ID="$("$ROOT_DIR/scripts/resolve-developer-id.sh" "$CODESIGN_ID")"
fi

if [[ -z "$VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS" && -f "$GENERATED_VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS" ]]; then
  VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS="$GENERATED_VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS"
fi

sign_file() {
  local path="$1"
  if /usr/bin/file -b "$path" | grep -q 'Mach-O'; then
    echo "Signing executable: ${path#$APP_PATH/}"
    /usr/bin/codesign --force --sign "$CODESIGN_ID" --options runtime --timestamp "$path"
  fi
}

sign_bundle() {
  local path="$1"
  echo "Signing nested bundle: ${path#$APP_PATH/}"
  local args=(--force --sign "$CODESIGN_ID" --options runtime --timestamp)
  if [[ "$path" == *.systemextension ]]; then
    if [[ -n "$VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS" ]]; then
      [[ -f "$VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS" ]] \
        || die "Extension entitlements file not found: $VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS"
      args+=(--entitlements "$VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS")
    elif [[ "${WINDOWSNAP_ALLOW_DEVELOPMENT_ENTITLEMENTS:-0}" == "1" \
      && -f "$SOURCE_VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS" ]]; then
      echo "Using development extension entitlements: $SOURCE_VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS"
      args+=(--entitlements "$SOURCE_VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS")
    else
      die "Generated extension entitlements are required for signed virtual camera builds"
    fi
  fi
  args+=("$path")
  /usr/bin/codesign "${args[@]}"
}

# BSD find's -depth traversal guarantees children are signed before containers.
while IFS= read -r -d '' path; do
  if [[ -f "$path" ]]; then
    sign_file "$path"
  else
    sign_bundle "$path"
  fi
done < <(/usr/bin/find "$APP_PATH/Contents" -depth \
  \( -type f \( -perm +111 -o -name '*.dylib' \) -o -type d \
    \( -name '*.framework' -o -name '*.xpc' -o \
       -name '*.appex' -o -name '*.app' -o -name '*.bundle' -o \
       -name '*.systemextension' \) \) \
  -print0)

outer_args=(--force --sign "$CODESIGN_ID" --options runtime --timestamp)
if [[ -n "$ENTITLEMENTS_FILE" ]]; then
  [[ -f "$ENTITLEMENTS_FILE" ]] || die "Entitlements file not found: $ENTITLEMENTS_FILE"
  outer_args+=(--entitlements "$ENTITLEMENTS_FILE")
fi
outer_args+=("$APP_PATH")

echo "Signing outer app bundle"
/usr/bin/codesign "${outer_args[@]}"
/usr/bin/codesign --verify --strict --verbose=2 "$APP_PATH"
