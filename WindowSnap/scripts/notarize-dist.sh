#!/usr/bin/env bash
set -euo pipefail

# Notarize dist/WindowSnap.zip (already Developer-ID signed), staple the app, re-zip.
# Does not re-sign — run after scripts/build-universal-bundle.sh with CODESIGN_ID set.
#
# Auth (pick one):
#   App Store Connect API key:
#     ASC_KEY_ID, ASC_KEY_ISSUER_ID, ASC_KEY_P8 (private key PEM as multiline env)
#   Apple ID + app-specific password:
#     APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, APPLE_TEAM_ID

APP_NAME="WindowSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/${APP_NAME}.app"
ZIP_PATH="$DIST_DIR/${APP_NAME}.zip"

die() {
  echo "❌ $*" >&2
  exit 1
}

if [[ ! -d "$APP_PATH" ]]; then
  die "Missing $APP_PATH — run build-universal-bundle.sh first."
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  die "Missing $ZIP_PATH — run build-universal-bundle.sh first."
fi

submit_args=(submit "$ZIP_PATH" --wait)

if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_KEY_ISSUER_ID:-}" && -n "${ASC_KEY_P8:-}" ]]; then
  tmp_key="$(mktemp -t windowsnap-asc-key.XXXXXX)"
  # shellcheck disable=SC2064
  trap 'rm -f "$tmp_key"' EXIT
  printf '%s\n' "$ASC_KEY_P8" >"$tmp_key"
  chmod 600 "$tmp_key"
  submit_args+=(--key "$tmp_key" --key-id "$ASC_KEY_ID" --issuer "$ASC_KEY_ISSUER_ID")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  submit_args+=(--apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID")
else
  die "Set either (ASC_KEY_ID, ASC_KEY_ISSUER_ID, ASC_KEY_P8) or (APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, APPLE_TEAM_ID)."
fi

echo "📤 Submitting $ZIP_PATH for notarization..."
xcrun notarytool "${submit_args[@]}"

echo "📎 Stapling ticket to $APP_PATH..."
xcrun stapler staple "$APP_PATH"

echo "📦 Recreating zip with stapled app..."
rm -f "$ZIP_PATH"
( cd "$DIST_DIR" && zip -qry "${APP_NAME}.zip" "${APP_NAME}.app" )

echo "🔎 Gatekeeper check (informational)..."
set +e
spctl -a -vv "$APP_PATH" 2>&1
spctl_rc=$?
set -e
if [[ $spctl_rc -ne 0 ]]; then
  echo "⚠️  spctl exited $spctl_rc — verify on another machine if needed."
fi

echo "✅ Notarization complete: $ZIP_PATH"
