#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

APP_PATH="${1:-}"
CODESIGN_ID="${2:-}"
ENTITLEMENTS_FILE="${3:-}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS="$ROOT_DIR/WindowSnapVirtualCameraExtension/WindowSnapVirtualCameraExtension.entitlements"

[[ -d "$APP_PATH" ]] || die "App bundle not found: $APP_PATH"
[[ -n "$CODESIGN_ID" ]] || die "A Developer ID Application identity or fingerprint is required"

CODESIGN_ID="$("$ROOT_DIR/scripts/resolve-developer-id.sh" "$CODESIGN_ID")"

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
  if [[ "$path" == *.systemextension && -f "$VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS" ]]; then
    args+=(--entitlements "$VIRTUAL_CAMERA_EXTENSION_ENTITLEMENTS")
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
