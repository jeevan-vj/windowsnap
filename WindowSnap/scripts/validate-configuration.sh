#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
read_plist() { /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null; }
has_plist_key() { /usr/libexec/PlistBuddy -c "Print :$2" "$1" >/dev/null 2>&1; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE=""
REQUIRE_SIGNATURE=false

while (( $# > 0 )); do
  case "$1" in
    --root) ROOT_DIR="$(cd "$2" && pwd)"; shift 2 ;;
    --bundle) BUNDLE="$2"; shift 2 ;;
    --signed) REQUIRE_SIGNATURE=true; shift ;;
    *) die "Unknown option: $1" ;;
  esac
done

PLIST="$ROOT_DIR/WindowSnap/App/Info.plist"
ENTITLEMENTS="$ROOT_DIR/WindowSnap.entitlements"
VERSION_FILE="$ROOT_DIR/VERSION"
BUILD_FILE="$ROOT_DIR/BUILD_NUMBER"
PACKAGE="$ROOT_DIR/Package.swift"

[[ -f "$PLIST" ]] || die "Missing Info.plist"
[[ -f "$ENTITLEMENTS" ]] || die "Missing reviewed entitlements file"
[[ -f "$VERSION_FILE" ]] || die "Missing VERSION"
[[ -f "$BUILD_FILE" ]] || die "Missing BUILD_NUMBER"
plutil -lint "$PLIST" >/dev/null || die "Info.plist is invalid"
plutil -lint "$ENTITLEMENTS" >/dev/null || die "Entitlements plist is invalid"

VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
BUILD="$(tr -d '[:space:]' < "$BUILD_FILE")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]] || die "VERSION is not a release SemVer"
[[ "$BUILD" =~ ^[1-9][0-9]*$ ]] || die "BUILD_NUMBER must be a positive integer"

for key in NSMainStoryboardFile SMLoginItemSetEnabled NSAccessibilityUsageDescription; do
  ! has_plist_key "$PLIST" "$key" || die "Forbidden stale Info.plist key: $key"
done

[[ "$(read_plist "$PLIST" CFBundleDisplayName)" == WindowSnap ]] || die "Unexpected app display name"
[[ "$(read_plist "$PLIST" CFBundleExecutable)" == WindowSnap ]] || die "Unexpected executable name"
[[ "$(read_plist "$PLIST" CFBundleIdentifier)" == com.windowsnap.app ]] || die "Unexpected bundle identifier"
[[ "$(read_plist "$PLIST" CFBundleShortVersionString)" == "$VERSION" ]] || die "Info.plist marketing version differs from VERSION"
[[ "$(read_plist "$PLIST" CFBundleVersion)" == "$BUILD" ]] || die "Info.plist build differs from BUILD_NUMBER"
[[ "$(read_plist "$PLIST" LSMinimumSystemVersion)" == 13.0 ]] || die "Info.plist deployment target must be macOS 13.0"
[[ "$(read_plist "$PLIST" NSScreenCaptureUsageDescription)" == *"Region Share"* ]] || die "Screen Recording disclosure must name Region Share"
[[ "$(read_plist "$PLIST" NSHumanReadableCopyright)" == *"2026 WindowSnap"* ]] || die "Copyright metadata is not current"

ENTITLEMENT_KEYS="$(/usr/libexec/PlistBuddy -c Print "$ENTITLEMENTS" | sed -n 's/^[[:space:]]*\([^=[:space:]][^=]*\) =.*/\1/p')"
[[ -z "$ENTITLEMENT_KEYS" ]] || die "Unreviewed production entitlement(s): $ENTITLEMENT_KEYS"

grep -Fq '.macOS(.v13)' "$PACKAGE" || die "SwiftPM deployment target must be macOS 13"
for script in build_bundle.sh build-universal-bundle.sh; do
  grep -Fq -- '--minimum-deployment-target 13.0' "$ROOT_DIR/scripts/$script" || die "$script asset target differs from macOS 13.0"
done

if [[ -n "$BUNDLE" ]]; then
  BUILT_PLIST="$BUNDLE/Contents/Info.plist"
  [[ -f "$BUILT_PLIST" ]] || die "Built bundle has no Info.plist"
  plutil -lint "$BUILT_PLIST" >/dev/null || die "Built Info.plist is invalid"
  for key in NSMainStoryboardFile SMLoginItemSetEnabled NSAccessibilityUsageDescription; do
    ! has_plist_key "$BUILT_PLIST" "$key" || die "Built bundle contains forbidden key: $key"
  done
  [[ "$(read_plist "$BUILT_PLIST" CFBundleIdentifier)" == com.windowsnap.app ]] || die "Built bundle identifier mismatch"
  [[ "$(read_plist "$BUILT_PLIST" CFBundleShortVersionString)" == "$VERSION" ]] || die "Built marketing version mismatch"
  [[ "$(read_plist "$BUILT_PLIST" CFBundleVersion)" == "$BUILD" ]] || die "Built build number mismatch"
  [[ "$(read_plist "$BUILT_PLIST" LSMinimumSystemVersion)" == 13.0 ]] || die "Built deployment target mismatch"
  [[ "$(read_plist "$BUILT_PLIST" NSScreenCaptureUsageDescription)" == *"Region Share"* ]] || die "Built Screen Recording disclosure mismatch"
  if [[ "$REQUIRE_SIGNATURE" == true ]]; then
    codesign --verify --strict "$BUNDLE" >/dev/null 2>&1 || die "Built app signature is invalid"
    SIGNED_ENTITLEMENTS="$(codesign -d --entitlements - "$BUNDLE" 2>&1)" || die "Cannot inspect signed entitlements"
    if grep -Eq '\[Key\]|<key>' <<< "$SIGNED_ENTITLEMENTS"; then
      die "Signed entitlements differ from the reviewed empty entitlement set"
    fi
  fi
fi

echo "Configuration valid: WindowSnap $VERSION ($BUILD), macOS 13.0+"
