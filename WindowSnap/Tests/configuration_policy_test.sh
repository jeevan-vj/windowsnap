#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$ROOT_DIR/scripts/validate-configuration.sh"
failures=0

pass() { printf 'ok - %s\n' "$1"; }
fail() { printf 'not ok - %s\n' "$1" >&2; failures=$((failures + 1)); }

expect_success() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then pass "$description"; else fail "$description"; fi
}

expect_failure() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then fail "$description"; else pass "$description"; fi
}

if [[ -x "$VALIDATOR" ]]; then
  pass "configuration validator is executable"
else
  fail "configuration validator is executable"
fi

expect_success "source configuration passes validation" "$VALIDATOR"

if grep -Eq 'PlistBuddy.*PLIST_SOURCE|PlistBuddy.*"\$PLIST_SOURCE"' \
  "$ROOT_DIR/scripts/build_bundle.sh" "$ROOT_DIR/scripts/build-universal-bundle.sh"; then
  fail "bundle builders never mutate the source plist"
else
  pass "bundle builders never mutate the source plist"
fi

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
cp -R "$ROOT_DIR/." "$FIXTURE/WindowSnap"

cp -R "$ROOT_DIR/." "$FIXTURE/BumpFixture"
OLD_BUILD="$(tr -d '[:space:]' < "$FIXTURE/BumpFixture/BUILD_NUMBER")"
if "$FIXTURE/BumpFixture/scripts/bump-version.sh" patch >/dev/null &&
   [[ "$(tr -d '[:space:]' < "$FIXTURE/BumpFixture/BUILD_NUMBER")" -eq $((OLD_BUILD + 1)) ]] &&
   "$VALIDATOR" --root "$FIXTURE/BumpFixture" >/dev/null; then
  pass "version bump increments build metadata and keeps mirrors synchronized"
else
  fail "version bump increments build metadata and keeps mirrors synchronized"
fi

PLIST="$FIXTURE/WindowSnap/WindowSnap/App/Info.plist"
ENTITLEMENTS="$FIXTURE/WindowSnap/WindowSnap.entitlements"
EXPECTED_VERSION="$(tr -d '[:space:]' < "$FIXTURE/WindowSnap/VERSION")"

/usr/libexec/PlistBuddy -c 'Add :NSMainStoryboardFile string Main' "$PLIST" >/dev/null 2>&1 || true
expect_failure "stale storyboard key is rejected" "$VALIDATOR" --root "$FIXTURE/WindowSnap"
/usr/libexec/PlistBuddy -c 'Delete :NSMainStoryboardFile' "$PLIST"

/usr/libexec/PlistBuddy -c 'Delete :NSScreenCaptureUsageDescription' "$PLIST"
expect_failure "missing Screen Recording disclosure is rejected" "$VALIDATOR" --root "$FIXTURE/WindowSnap"
/usr/libexec/PlistBuddy -c 'Add :NSScreenCaptureUsageDescription string Region Share captures only the selected screen region.' "$PLIST"

/usr/libexec/PlistBuddy -c 'Delete :com.apple.security.automation.apple-events' "$ENTITLEMENTS" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Add :com.apple.security.automation.apple-events bool true' "$ENTITLEMENTS"
expect_failure "unreviewed entitlement drift is rejected" "$VALIDATOR" --root "$FIXTURE/WindowSnap"
/usr/libexec/PlistBuddy -c 'Delete :com.apple.security.automation.apple-events' "$ENTITLEMENTS"

printf '9.9.9\n' > "$FIXTURE/WindowSnap/VERSION"
expect_failure "marketing version mismatch is rejected" "$VALIDATOR" --root "$FIXTURE/WindowSnap"
printf '%s\n' "$EXPECTED_VERSION" > "$FIXTURE/WindowSnap/VERSION"

/usr/libexec/PlistBuddy -c 'Set :LSMinimumSystemVersion 12.0' "$PLIST"
expect_failure "deployment target mismatch is rejected" "$VALIDATOR" --root "$FIXTURE/WindowSnap"
/usr/libexec/PlistBuddy -c 'Set :LSMinimumSystemVersion 13.0' "$PLIST"

/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion invalid' "$PLIST"
expect_failure "invalid build metadata is rejected" "$VALIDATOR" --root "$FIXTURE/WindowSnap"

cp -R "$FIXTURE/WindowSnap/WindowSnap/App/Info.plist" "$FIXTURE/BuiltInfo.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(cat "$FIXTURE/WindowSnap/BUILD_NUMBER")" "$FIXTURE/BuiltInfo.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier invalid.bundle' "$FIXTURE/BuiltInfo.plist"
mkdir -p "$FIXTURE/WindowSnap.app/Contents"
cp "$FIXTURE/BuiltInfo.plist" "$FIXTURE/WindowSnap.app/Contents/Info.plist"
expect_failure "built bundle metadata drift is rejected" "$VALIDATOR" --root "$ROOT_DIR" --bundle "$FIXTURE/WindowSnap.app"

if (( failures > 0 )); then
  printf '\n%d configuration policy test(s) failed.\n' "$failures" >&2
  exit 1
fi

printf '\nAll configuration policy tests passed.\n'
