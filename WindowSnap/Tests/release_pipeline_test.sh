#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"
failures=0

pass() { printf 'ok - %s\n' "$1"; }
fail() { printf 'not ok - %s\n' "$1" >&2; failures=$((failures + 1)); }

assert_contains() {
  local file="$1" pattern="$2" description="$3"
  if grep -Eq -- "$pattern" "$file"; then pass "$description"; else fail "$description"; fi
}

assert_not_contains() {
  local file="$1" pattern="$2" description="$3"
  if grep -Eq -- "$pattern" "$file"; then fail "$description"; else pass "$description"; fi
}

assert_executable() {
  local file="$1" description="$2"
  if [[ -x "$file" ]]; then pass "$description"; else fail "$description"; fi
}

assert_executable "$SCRIPTS_DIR/release.sh" "canonical release command is executable"
assert_executable "$SCRIPTS_DIR/sign-nested-components.sh" "explicit nested signing helper exists"
assert_executable "$SCRIPTS_DIR/verify-release.sh" "release artifact verifier exists"

assert_not_contains "$SCRIPTS_DIR/release.sh" 'skip-notarize|SKIP_NOTARIZE' "production release cannot skip notarization"
assert_not_contains "$SCRIPTS_DIR/release.sh" 'codesign[^\n]*--deep|--deep[^\n]*codesign' "production release does not use codesign --deep"
assert_not_contains "$SCRIPTS_DIR/sign-and-notarize.sh" 'codesign[^\n]*--deep|--deep[^\n]*codesign' "notarization path does not use codesign --deep"
assert_not_contains "$SCRIPTS_DIR/build-universal-bundle.sh" '^[[:space:]]*--deep([[:space:]]|$)' "universal bundle signing does not use --deep"

assert_contains "$SCRIPTS_DIR/release.sh" 'Developer ID Application' "release requires a Developer ID Application identity"
assert_contains "$SCRIPTS_DIR/release.sh" 'NOTARY_PROFILE' "release requires a Keychain notarization profile"
assert_contains "$SCRIPTS_DIR/sign-and-notarize.sh" 'sign-nested-components\.sh' "release signing stage explicitly signs nested code"
assert_contains "$SCRIPTS_DIR/release.sh" 'verify-release\.sh' "release delegates final artifact verification"
assert_contains "$SCRIPTS_DIR/release.sh" '--publish' "publishing is an explicit release action"

assert_contains "$SCRIPTS_DIR/sign-and-notarize.sh" 'notarytool submit' "app notarization uses notarytool"
assert_contains "$SCRIPTS_DIR/sign-and-notarize.sh" 'status:[[:space:]]*Accepted|--output-format[[:space:]]+json' "notarization acceptance is checked deterministically"
assert_contains "$SCRIPTS_DIR/sign-and-notarize.sh" 'stapler validate' "app stapling is validated"

assert_contains "$SCRIPTS_DIR/verify-release.sh" 'codesign --verify --strict --verbose=2' "app signature is verified strictly"
assert_contains "$SCRIPTS_DIR/verify-release.sh" 'lipo.*arm64' "arm64 architecture is required"
assert_contains "$SCRIPTS_DIR/verify-release.sh" 'lipo.*x86_64' "x86_64 architecture is required"
assert_contains "$SCRIPTS_DIR/verify-release.sh" 'spctl.*candidate' "Gatekeeper assesses the app"
assert_contains "$SCRIPTS_DIR/verify-release.sh" 'spctl.*DMG_PATH' "Gatekeeper assesses the DMG"
assert_contains "$SCRIPTS_DIR/verify-release.sh" 'stapler validate' "stapled tickets are validated"
assert_contains "$SCRIPTS_DIR/verify-release.sh" 'CFBundleShortVersionString' "artifact versions are compared"
assert_contains "$SCRIPTS_DIR/verify-release.sh" 'CFBundleVersion' "artifact build numbers are compared"

assert_contains "$SCRIPTS_DIR/build-adhoc-release.sh" 'local-only' "ad-hoc artifacts are isolated as local-only"
assert_not_contains "$SCRIPTS_DIR/build-adhoc-release.sh" 'GitHub Release|ready for GitHub|gh release' "ad-hoc artifacts are not presented as publishable"

assert_not_contains "$ROOT_DIR/../README.md" 'xattr[[:space:]]+-d|Open Anyway|bypass Gatekeeper|isn.t notarized' "README does not instruct users to bypass Gatekeeper"
assert_contains "$ROOT_DIR/../DISTRIBUTION_GUIDE.md" 'scripts/release\.sh' "distribution guide names one canonical command"
assert_contains "$ROOT_DIR/../DISTRIBUTION_GUIDE.md" 'clean-machine|Clean-machine' "distribution guide includes a clean-machine smoke test"
assert_not_contains "$ROOT_DIR/../DISTRIBUTION_GUIDE.md" '--password[[:space:]]+"?[^[:space:]]+|APP_SPECIFIC_PASSWORD' "distribution guide never places notarization passwords in command arguments"
assert_contains "$ROOT_DIR/../DISTRIBUTION_GUIDE.md" 'interactive|prompt' "distribution guide uses interactive Keychain credential setup"

WORKFLOW="$ROOT_DIR/../.github/workflows/release-macos.yml"
assert_not_contains "$WORKFLOW" 'notarize-dist\.sh|softprops/action-gh-release' "live workflow has no retired or duplicate release path"
assert_contains "$WORKFLOW" 'scripts/release\.sh[[:space:]]+--publish' "live workflow delegates publishing to the canonical release command"
assert_contains "$WORKFLOW" 'notarytool store-credentials' "live workflow creates the canonical notarytool Keychain profile"

assert_not_contains "$ROOT_DIR/../README.md" 'scripts/(build_bundle|sign-and-notarize|distribute|package_dmg)\.sh|right-click method' "README contains no legacy distribution or Gatekeeper-bypass instructions"
assert_not_contains "$SCRIPTS_DIR/package_dmg.sh" 'hdiutil create|codesign.*continuing|NOTARIZE_DMG_STEPS' "legacy package_dmg route cannot create unverified artifacts"
assert_contains "$SCRIPTS_DIR/package_dmg.sh" 'release\.sh' "legacy package_dmg route delegates users to the canonical release"
assert_not_contains "$SCRIPTS_DIR/windowsnap.sh" 'distribute\.sh|package_dmg\.sh|build_bundle\.sh' "management console exposes no unsafe distribution routes"
assert_contains "$SCRIPTS_DIR/windowsnap.sh" 'release\.sh' "management console delegates production candidates to canonical release"
assert_contains "$SCRIPTS_DIR/windowsnap.sh" 'build-adhoc-release\.sh' "management console delegates local packages to local-only build"

if env -u CODESIGN_ID -u NOTARY_PROFILE "$SCRIPTS_DIR/release.sh" --skip-notarize >/dev/null 2>&1; then
  fail "removed skip-notarize option is rejected"
else
  pass "removed skip-notarize option is rejected"
fi

if env -u CODESIGN_ID -u NOTARY_PROFILE "$SCRIPTS_DIR/release.sh" >/dev/null 2>&1; then
  fail "production release fails before building without signing credentials"
else
  pass "production release fails before building without signing credentials"
fi

if (( failures > 0 )); then
  printf '\n%d release policy test(s) failed.\n' "$failures" >&2
  exit 1
fi

printf '\nAll release policy tests passed.\n'
