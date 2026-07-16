#!/usr/bin/env bash
set -euo pipefail

# Canonical production release command:
#   CODESIGN_ID="Developer ID Application: ..." NOTARY_PROFILE="windowsnap-notary" ./scripts/release.sh
# Add --publish only after reviewing the verified artifacts. Publishing never has
# an option to bypass signing, notarization, stapling, or verification.

die() { echo "ERROR: $*" >&2; exit 1; }
require_command() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
PRODUCTION_DIR="$DIST_DIR/production"
APP_NAME="WindowSnap"
PUBLISH=false
DRAFT=false

for arg in "$@"; do
  case "$arg" in
    --publish) PUBLISH=true ;;
    --draft) DRAFT=true ;;
    -h|--help)
      sed -n '3,6p' "$0"
      exit 0
      ;;
    *) die "Unknown option: $arg" ;;
  esac
done

[[ "${CODESIGN_ID:-}" == Developer\ ID\ Application:* ]] || \
  die "Set CODESIGN_ID to an installed Developer ID Application identity"
[[ -n "${NOTARY_PROFILE:-}" ]] || \
  die "Set NOTARY_PROFILE to a notarytool Keychain profile"

for command_name in security swift lipo codesign xcrun hdiutil ditto spctl shasum; do
  require_command "$command_name"
done

# Match the exact configured identity without printing the Keychain inventory.
if ! /usr/bin/security find-identity -v -p codesigning 2>/dev/null | /usr/bin/grep -F "\"$CODESIGN_ID\"" >/dev/null; then
  die "The configured Developer ID Application identity is not installed or valid"
fi
if [[ "$PUBLISH" == true ]]; then
  require_command gh
  gh auth status >/dev/null 2>&1 || die "GitHub CLI authentication is required for --publish"
fi

VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]] || die "Invalid VERSION: $VERSION"

echo "Building WindowSnap $VERSION for production"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
"$ROOT_DIR/scripts/build-universal-bundle.sh"
"$ROOT_DIR/scripts/sign-and-notarize.sh"
"$ROOT_DIR/scripts/create-signed-dmg.sh" >/dev/null

APP_PATH="$DIST_DIR/$APP_NAME.app"
SOURCE_ZIP="$DIST_DIR/$APP_NAME.zip"
SOURCE_DMG="$DIST_DIR/$APP_NAME-$VERSION-macOS-notarized.dmg"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
ZIP_NAME="$APP_NAME-$VERSION-macOS-notarized.zip"
DMG_NAME="$APP_NAME-$VERSION-macOS-notarized.dmg"

"$ROOT_DIR/scripts/verify-release.sh" "$APP_PATH" "$SOURCE_ZIP" "$SOURCE_DMG" "$VERSION" "$BUILD"

mkdir -p "$PRODUCTION_DIR"
/usr/bin/ditto "$APP_PATH" "$PRODUCTION_DIR/$APP_NAME.app"
cp "$SOURCE_ZIP" "$PRODUCTION_DIR/$ZIP_NAME"
cp "$SOURCE_DMG" "$PRODUCTION_DIR/$DMG_NAME"
(
  cd "$PRODUCTION_DIR"
  /usr/bin/shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256"
  /usr/bin/shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
)

echo "Verified production artifacts: $PRODUCTION_DIR"
if [[ "$PUBLISH" == true ]]; then
  release_args=(release create "v$VERSION" --title "WindowSnap $VERSION" --generate-notes)
  [[ "$DRAFT" == true ]] && release_args+=(--draft)
  release_args+=(
    "$PRODUCTION_DIR/$ZIP_NAME"
    "$PRODUCTION_DIR/$DMG_NAME"
    "$PRODUCTION_DIR/$ZIP_NAME.sha256"
    "$PRODUCTION_DIR/$DMG_NAME.sha256"
  )
  gh "${release_args[@]}"
  echo "Published only after notarization and full artifact verification."
else
  echo "Review these candidates. Create a fresh verified draft with --publish --draft when ready."
fi
