#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

APP_NAME="WindowSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION-macOS-notarized.dmg"
SOURCE_DIR="$DIST_DIR/dmg-source"

[[ -d "$APP_PATH" ]] || die "Missing $APP_PATH"
[[ "${CODESIGN_ID:-}" == Developer\ ID\ Application:* ]] || die "CODESIGN_ID must name a Developer ID Application identity"
[[ -n "${NOTARY_PROFILE:-}" ]] || die "NOTARY_PROFILE must name a notarytool Keychain profile"

rm -rf "$SOURCE_DIR" "$DMG_PATH"
mkdir -p "$SOURCE_DIR"
trap 'rm -rf "$SOURCE_DIR"' EXIT
/usr/bin/ditto "$APP_PATH" "$SOURCE_DIR/$APP_NAME.app"
ln -s /Applications "$SOURCE_DIR/Applications"
/usr/bin/hdiutil create -quiet -ov -srcfolder "$SOURCE_DIR" -volname "$APP_NAME" -fs HFS+ -format UDZO "$DMG_PATH"
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
