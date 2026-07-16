#!/usr/bin/env bash
set -euo pipefail

# Canonical production release command:
#   CODESIGN_ID="Developer ID Application: ..." NOTARY_PROFILE="windowsnap-notary" ./scripts/release.sh
# Add --publish only after reviewing the verified artifacts. Publishing never has
# an option to bypass signing, notarization, stapling, or verification.

die() { echo "ERROR: $*" >&2; exit 1; }
require_command() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
PRODUCTION_DIR="$DIST_DIR/production"
APP_NAME="WindowSnap"
PUBLISH=false
DRAFT=false
EXPECTED_RELEASE_COMMIT=""

resolve_remote_tag_commit() {
  local tag="$1"
  local remote_refs remote_commit

  remote_refs="$(git -C "$ROOT_DIR" ls-remote --exit-code origin \
    "refs/tags/$tag" "refs/tags/$tag^{}" 2>/dev/null)" || return 1
  remote_commit="$(printf '%s\n' "$remote_refs" | \
    awk '$2 ~ /\^\{\}$/ { print $1; exit }')"
  if [[ -z "$remote_commit" ]]; then
    remote_commit="$(printf '%s\n' "$remote_refs" | awk 'NR == 1 { print $1 }')"
  fi
  [[ -n "$remote_commit" ]] || return 1
  printf '%s\n' "$remote_commit"
}

validate_publish_source() {
  local tag="v$VERSION"
  local status remote_commit head_commit

  git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
    die "Publishing requires a Git working tree"
  status="$(git -C "$ROOT_DIR" status --porcelain --untracked-files=normal)"
  [[ -z "$status" ]] || die "Publishing requires a clean working tree"

  if ! remote_commit="$(resolve_remote_tag_commit "$tag")"; then
    die "Remote tag $tag does not exist on origin"
  fi

  head_commit="$(git -C "$ROOT_DIR" rev-parse HEAD)"
  [[ "$head_commit" == "$remote_commit" ]] || \
    die "HEAD must exactly match remote tag $tag ($remote_commit)"
  EXPECTED_RELEASE_COMMIT="$remote_commit"
}

revalidate_publish_source() {
  local tag="v$VERSION"
  local status head_commit remote_commit

  [[ -n "$EXPECTED_RELEASE_COMMIT" ]] || die "Expected release commit was not preserved"
  status="$(git -C "$ROOT_DIR" status --porcelain --untracked-files=normal)"
  [[ -z "$status" ]] || die "Publishing requires a clean working tree; files changed during release"

  head_commit="$(git -C "$ROOT_DIR" rev-parse HEAD)"
  [[ "$head_commit" == "$EXPECTED_RELEASE_COMMIT" ]] || \
    die "HEAD changed during release; expected $EXPECTED_RELEASE_COMMIT, found $head_commit"

  if ! remote_commit="$(resolve_remote_tag_commit "$tag")"; then
    die "Remote tag $tag does not exist on origin during final publish validation"
  fi
  [[ "$remote_commit" == "$EXPECTED_RELEASE_COMMIT" ]] || \
    die "Remote tag $tag changed during release; expected $EXPECTED_RELEASE_COMMIT, found $remote_commit"
}

publish_verified_release() {
  local -a release_args
  release_args=(release create "v$VERSION" --verify-tag --title "WindowSnap $VERSION" --generate-notes)
  [[ "$DRAFT" == true ]] && release_args+=(--draft)
  release_args+=(
    "$PRODUCTION_DIR/$ZIP_NAME"
    "$PRODUCTION_DIR/$DMG_NAME"
    "$PRODUCTION_DIR/$ZIP_NAME.sha256"
    "$PRODUCTION_DIR/$DMG_NAME.sha256"
  )

  # This must remain immediately before GitHub publishing. A release build can
  # take long enough for the worktree, HEAD, or remote tag to change meanwhile.
  revalidate_publish_source
  gh "${release_args[@]}"
}

main() {
  local arg
  PUBLISH=false
  DRAFT=false

  for arg in "$@"; do
    case "$arg" in
      --publish) PUBLISH=true ;;
      --draft) DRAFT=true ;;
      -h|--help)
        sed -n '3,6p' "${BASH_SOURCE[0]}"
        exit 0
        ;;
      *) die "Unknown option: $arg" ;;
    esac
  done

  VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
  [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]] || die "Invalid VERSION: $VERSION"

  if [[ "$PUBLISH" == true ]]; then
    require_command git
    validate_publish_source
  fi

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
    publish_verified_release
    echo "Published only after notarization and full artifact verification."
  else
    echo "Review these candidates. Create a fresh verified draft with --publish --draft when ready."
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
