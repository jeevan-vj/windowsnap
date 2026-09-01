#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

APP_NAME="WindowSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION-macOS-notarized.dmg"
RW_DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION-readwrite.dmg"

[[ -d "$APP_PATH" ]] || die "Missing $APP_PATH"
[[ -n "${CODESIGN_ID:-}" ]] || die "CODESIGN_ID must name a Developer ID Application identity or fingerprint"
[[ -n "${NOTARY_PROFILE:-}" ]] || die "NOTARY_PROFILE must name a notarytool Keychain profile"

CODESIGN_ID="$("$ROOT_DIR/scripts/resolve-developer-id.sh" "$CODESIGN_ID")"

MOUNT_DIR="$(mktemp -d -t windowsnap-dmg.XXXXXX)"
mounted=false
cleanup() {
  if [[ "$mounted" == true ]]; then
    /usr/bin/hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
  fi
  rm -rf "$MOUNT_DIR" "$RW_DMG_PATH"
}
trap cleanup EXIT

rm -f "$DMG_PATH" "$RW_DMG_PATH"
/usr/bin/hdiutil create -quiet -ov -size 64m -fs HFS+ -volname "$APP_NAME" -type UDIF "$RW_DMG_PATH"
/usr/bin/hdiutil attach "$RW_DMG_PATH" -nobrowse -mountpoint "$MOUNT_DIR" -quiet
mounted=true
/usr/bin/ditto "$APP_PATH" "$MOUNT_DIR/$APP_NAME.app"
ln -s /Applications "$MOUNT_DIR/Applications"
/usr/bin/hdiutil detach "$MOUNT_DIR" -quiet
mounted=false
/usr/bin/hdiutil convert "$RW_DMG_PATH" -format UDZO -ov -o "$DMG_PATH" >/dev/null
/usr/bin/codesign --force --sign "$CODESIGN_ID" --timestamp "$DMG_PATH"
/usr/bin/codesign --verify --strict --verbose=2 "$DMG_PATH"

echo "Submitting DMG for notarization (profile name and credentials are not logged)."
NOTARY_OUTPUT="$(/usr/bin/xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)"
NOTARY_STATUS="$(printf '%s' "$NOTARY_OUTPUT" | /usr/bin/plutil -extract status raw -o - -)"
NOTARY_ID="$(printf '%s' "$NOTARY_OUTPUT" | /usr/bin/plutil -extract id raw -o - -)"
[[ "$NOTARY_STATUS" == "Accepted" ]] || die "DMG notarization did not return status: Accepted (submission $NOTARY_ID)"

/usr/bin/xcrun stapler staple "$DMG_PATH"
/usr/bin/xcrun stapler validate "$DMG_PATH"
/usr/sbin/spctl -a -t open --context context:primary-signature -vv "$DMG_PATH"
echo "$DMG_PATH"
