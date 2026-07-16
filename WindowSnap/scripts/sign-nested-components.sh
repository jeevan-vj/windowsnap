#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

APP_PATH="${1:-}"
CODESIGN_ID="${2:-}"
ENTITLEMENTS_FILE="${3:-}"

[[ -d "$APP_PATH" ]] || die "App bundle not found: $APP_PATH"
[[ "$CODESIGN_ID" == Developer\ ID\ Application:* ]] || die "A Developer ID Application identity is required"

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
  /usr/bin/codesign --force --sign "$CODESIGN_ID" --options runtime --timestamp "$path"
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
       -name '*.appex' -o -name '*.app' -o -name '*.bundle' \) \) \
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
