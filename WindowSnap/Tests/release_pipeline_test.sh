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

workflow_run_blocks_contain() {
  local file="$1" pattern="$2"
  awk '
    /^[[:space:]]+run:[[:space:]]*\|[[:space:]]*$/ {
      in_run = 1
      match($0, /^[[:space:]]*/)
      run_indent = RLENGTH
      next
    }
    in_run {
      if ($0 ~ /^[[:space:]]*$/) {
        print
        next
      }
      match($0, /^[[:space:]]*/)
      if (RLENGTH <= run_indent) {
        in_run = 0
        next
      }
      print
    }
  ' "$file" | grep -Eq -- "$pattern"
}

assert_workflow_run_not_contains() {
  local file="$1" pattern="$2" description="$3"
  if workflow_run_blocks_contain "$file" "$pattern"; then fail "$description"; else pass "$description"; fi
}

assert_publish_preflight_fails_with() {
  local repo="$1" expected="$2" description="$3"
  local output
  if output="$(cd "$repo" && env -u CODESIGN_ID -u NOTARY_PROFILE ./scripts/release.sh --publish 2>&1)"; then
    fail "$description"
  elif grep -Fq -- "$expected" <<<"$output"; then
    pass "$description"
  else
    printf 'Expected error containing: %s\nActual output:\n%s\n' "$expected" "$output" >&2
    fail "$description"
  fi
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
assert_workflow_run_not_contains "$WORKFLOW" '\$\{\{[[:space:]]*(github\.event\.inputs\.tag|github\.ref)[[:space:]]*\}\}' "untrusted GitHub context is never interpolated directly into run scripts"
assert_contains "$WORKFLOW" 'REQUESTED_TAG:[[:space:]]*\$\{\{[[:space:]]*github\.event\.inputs\.tag[[:space:]]*\}\}' "manual tag input enters the shell only through an environment variable"
assert_contains "$WORKFLOW" 'TRIGGER_REF:[[:space:]]*\$\{\{[[:space:]]*github\.ref[[:space:]]*\}\}' "push ref enters the shell only through an environment variable"
assert_contains "$WORKFLOW" '\^v\[0-9\]\+\\\.\[0-9\]\+\\\.\[0-9\]\+\$' "workflow strictly validates release tags as vX.Y.Z"

workflow_mutant="$(mktemp)"
cp "$WORKFLOW" "$workflow_mutant"
sed 's/tag="\$REQUESTED_TAG"/tag="${{ github.event.inputs.tag }}"/' "$WORKFLOW" > "$workflow_mutant"
if workflow_run_blocks_contain "$workflow_mutant" '\$\{\{[[:space:]]*github\.event\.inputs\.tag[[:space:]]*\}\}'; then
  pass "workflow injection mutation is detected by the policy test"
else
  fail "workflow injection mutation is detected by the policy test"
fi
rm -f "$workflow_mutant"

assert_contains "$SCRIPTS_DIR/release.sh" 'git .*status --porcelain' "publish requires a clean working tree"
assert_contains "$SCRIPTS_DIR/release.sh" 'git .*ls-remote' "publish verifies the release tag on origin"
assert_contains "$SCRIPTS_DIR/release.sh" '--verify-tag' "GitHub release creation refuses to invent a missing tag"

preflight_tmp="$(mktemp -d)"
remote_repo="$preflight_tmp/remote.git"
work_repo="$preflight_tmp/work"
git init --bare "$remote_repo" >/dev/null
git init "$work_repo" >/dev/null
git -C "$work_repo" config user.name "WindowSnap Test"
git -C "$work_repo" config user.email "windowsnap-test@example.invalid"
mkdir -p "$work_repo/scripts"
cp "$SCRIPTS_DIR/release.sh" "$work_repo/scripts/release.sh"
chmod +x "$work_repo/scripts/release.sh"
printf '9.8.7\n' > "$work_repo/VERSION"
git -C "$work_repo" add VERSION scripts/release.sh
git -C "$work_repo" commit -m "release fixture" >/dev/null
release_commit="$(git -C "$work_repo" rev-parse HEAD)"
git -C "$work_repo" tag -a v9.8.7 -m "release fixture tag"
release_tag_object="$(git -C "$work_repo" rev-parse v9.8.7)"
git -C "$work_repo" remote add origin "$remote_repo"
git -C "$work_repo" push origin HEAD:refs/heads/main refs/tags/v9.8.7 >/dev/null

printf 'dirty\n' >> "$work_repo/untracked.txt"
assert_publish_preflight_fails_with "$work_repo" "clean working tree" "publish rejects untracked or modified files"
rm -f "$work_repo/untracked.txt"

git --git-dir="$remote_repo" update-ref -d refs/tags/v9.8.7
assert_publish_preflight_fails_with "$work_repo" "Remote tag v9.8.7 does not exist" "publish rejects a missing remote release tag without network access"
git --git-dir="$remote_repo" update-ref refs/tags/v9.8.7 "$release_tag_object"
assert_publish_preflight_fails_with "$work_repo" "Set CODESIGN_ID" "publish accepts a clean checkout at the exact annotated remote tag commit"

printf 'next\n' > "$work_repo/NEXT"
git -C "$work_repo" add NEXT
git -C "$work_repo" commit -m "commit after tag" >/dev/null
assert_publish_preflight_fails_with "$work_repo" "HEAD must exactly match remote tag v9.8.7" "publish rejects HEAD when it differs from the remote tag commit"
rm -rf "$preflight_tmp"

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
