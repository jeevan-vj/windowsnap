#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

APP_NAME="WindowSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/$APP_NAME.app"
ZIP_PATH="$ROOT_DIR/dist/$APP_NAME.zip"

[[ -d "$APP_PATH" ]] || die "Missing $APP_PATH"
[[ "${CODESIGN_ID:-}" == Developer\ ID\ Application:* ]] || die "CODESIGN_ID must name a Developer ID Application identity"
[[ -n "${NOTARY_PROFILE:-}" ]] || die "NOTARY_PROFILE must name a notarytool Keychain profile"

"$ROOT_DIR/scripts/sign-nested-components.sh" "$APP_PATH" "$CODESIGN_ID" "$ROOT_DIR/WindowSnap.entitlements"

rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Submitting app archive for notarization (profile name and credentials are not logged)."
NOTARY_OUTPUT="$(/usr/bin/xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)"
NOTARY_STATUS="$(printf '%s' "$NOTARY_OUTPUT" | /usr/bin/plutil -extract status raw -o - -)"
NOTARY_ID="$(printf '%s' "$NOTARY_OUTPUT" | /usr/bin/plutil -extract id raw -o - -)"
[[ "$NOTARY_STATUS" == "Accepted" ]] || die "Apple notarization did not return status: Accepted (submission $NOTARY_ID)"
echo "Notarization Accepted (submission $NOTARY_ID)."

/usr/bin/xcrun stapler staple "$APP_PATH"
/usr/bin/xcrun stapler validate "$APP_PATH"
/usr/bin/codesign --verify --strict --verbose=2 "$APP_PATH"
/usr/sbin/spctl -a -t execute -vv "$APP_PATH"

# The public ZIP must contain the stapled app, not the submitted pre-staple copy.
rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
