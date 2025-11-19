#!/usr/bin/env bash
set -euo pipefail

# Semantic versioning bump script for WindowSnap
# Usage: ./bump-version.sh [major|minor|patch]

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "❌ VERSION file not found at $VERSION_FILE" >&2
  exit 1
fi

CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')

if [[ -z "$CURRENT_VERSION" ]]; then
  echo "❌ VERSION file is empty" >&2
  exit 1
fi

# Validate current version format (semantic versioning)
if [[ ! "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$ ]]; then
  echo "❌ Invalid version format: $CURRENT_VERSION" >&2
  echo "   Expected format: MAJOR.MINOR.PATCH (e.g., 1.2.0)" >&2
  exit 1
fi

# Parse version components (strip pre-release and build metadata for bumping)
VERSION_PARTS=$(echo "$CURRENT_VERSION" | cut -d'-' -f1 | cut -d'+' -f1)
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION_PARTS"

BUMP_TYPE="${1:-patch}"

case "$BUMP_TYPE" in
  major)
    NEW_MAJOR=$((MAJOR + 1))
    NEW_VERSION="$NEW_MAJOR.0.0"
    ;;
  minor)
    NEW_MINOR=$((MINOR + 1))
    NEW_VERSION="$MAJOR.$NEW_MINOR.0"
    ;;
  patch)
    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"
    ;;
  *)
    echo "❌ Invalid bump type: $BUMP_TYPE" >&2
    echo "   Usage: $0 [major|minor|patch]" >&2
    exit 1
    ;;
esac

# Update VERSION file
echo "$NEW_VERSION" > "$VERSION_FILE"

# Update Info.plist if it exists
PLIST_FILE="$ROOT_DIR/WindowSnap/App/Info.plist"
if [[ -f "$PLIST_FILE" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "$PLIST_FILE" 2>/dev/null || true
  echo "✅ Updated Info.plist"
fi

echo "✅ Version bumped: $CURRENT_VERSION → $NEW_VERSION"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Commit version bump: git add VERSION WindowSnap/WindowSnap/App/Info.plist && git commit -m \"Bump version to $NEW_VERSION\""
echo "  3. Tag release: git tag -a v$NEW_VERSION -m \"Release v$NEW_VERSION\""
echo "  4. Build: ./scripts/build-universal-bundle.sh"

