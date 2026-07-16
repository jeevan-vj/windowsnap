#!/usr/bin/env bash
set -euo pipefail

# Creates an ad-hoc signed build for local testing only. These artifacts are
# deliberately segregated from dist/production and must never be published.

APP_NAME="WindowSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
LOCAL_DIR="$DIST_DIR/local-only"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"

if [[ "${1:-}" == "--publish" ]]; then
  echo "ERROR: local-only builds cannot be published" >&2
  exit 1
fi
if (( $# > 0 )); then
  echo "Usage: $0" >&2
  exit 1
fi

echo "Building an ad-hoc signed LOCAL-ONLY artifact."
echo "It is not notarized and is not suitable for distribution."
unset CODESIGN_ID NOTARY_PROFILE
"$ROOT_DIR/scripts/build-universal-bundle.sh"

rm -rf "$LOCAL_DIR"
mkdir -p "$LOCAL_DIR"
mv "$DIST_DIR/$APP_NAME.app" "$LOCAL_DIR/$APP_NAME.app"
mv "$DIST_DIR/$APP_NAME.zip" "$LOCAL_DIR/$APP_NAME-$VERSION-local-only.zip"

echo "Local test artifacts: $LOCAL_DIR"
