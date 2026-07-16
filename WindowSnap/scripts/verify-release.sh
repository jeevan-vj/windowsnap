#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

APP_PATH="${1:-}"
ZIP_PATH="${2:-}"
DMG_PATH="${3:-}"
EXPECTED_VERSION="${4:-}"
EXPECTED_BUILD="${5:-}"

[[ -d "$APP_PATH" ]] || die "App bundle missing: $APP_PATH"
[[ -f "$ZIP_PATH" ]] || die "ZIP missing: $ZIP_PATH"
[[ -f "$DMG_PATH" ]] || die "DMG missing: $DMG_PATH"
[[ -n "$EXPECTED_VERSION" && -n "$EXPECTED_BUILD" ]] || die "Expected version and build are required"

verify_app() {
  local candidate="$1" label="$2" executable architectures version build
  executable="$candidate/Contents/MacOS/WindowSnap"
  [[ -x "$executable" ]] || die "$label executable is missing"
  architectures="$(/usr/bin/lipo -archs "$executable")"
  /usr/bin/lipo -verify_arch arm64 "$executable" || die "$label lacks arm64 ($architectures)"
  /usr/bin/lipo -verify_arch x86_64 "$executable" || die "$label lacks x86_64 ($architectures)"
  /usr/bin/codesign --verify --strict --verbose=2 "$candidate"
  /usr/bin/codesign -d --verbose=4 "$candidate" 2>&1 | grep -q 'Runtime Version' || die "$label lacks Hardened Runtime"
  /usr/bin/codesign -d --verbose=4 "$candidate" 2>&1 | grep -q 'Timestamp=' || die "$label lacks a secure timestamp"
  /usr/bin/xcrun stapler validate "$candidate"
  /usr/sbin/spctl -a -t execute -vv "$candidate"
  version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$candidate/Contents/Info.plist")"
  build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$candidate/Contents/Info.plist")"
  [[ "$version" == "$EXPECTED_VERSION" ]] || die "$label version $version != $EXPECTED_VERSION"
  [[ "$build" == "$EXPECTED_BUILD" ]] || die "$label build $build != $EXPECTED_BUILD"
}

tmp_dir="$(mktemp -d -t windowsnap-release-verify.XXXXXX)"
mount_dir="$tmp_dir/dmg"
mounted=false
cleanup() {
  if [[ "$mounted" == true ]]; then /usr/bin/hdiutil detach "$mount_dir" -quiet || true; fi
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

verify_app "$APP_PATH" "staged app"

mkdir -p "$tmp_dir/zip"
/usr/bin/ditto -x -k "$ZIP_PATH" "$tmp_dir/zip"
verify_app "$tmp_dir/zip/WindowSnap.app" "ZIP app"

mkdir -p "$mount_dir"
/usr/bin/hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$mount_dir" -quiet
mounted=true
verify_app "$mount_dir/WindowSnap.app" "DMG app"
/usr/bin/codesign --verify --strict --verbose=2 "$DMG_PATH"
/usr/bin/xcrun stapler validate "$DMG_PATH"
/usr/sbin/spctl -a -t open --context context:primary-signature -vv "$DMG_PATH"

echo "Verified version $EXPECTED_VERSION ($EXPECTED_BUILD) in the app, ZIP, and DMG."
