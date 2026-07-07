#!/usr/bin/env bash
set -euo pipefail

# Generate appcast.xml for Sparkle updates
# Usage: ./generate-appcast.sh [version] [repo-url]
#
# Environment variables:
#   SPARKLE_PRIVATE_KEY - Path to private key (default: ~/.sparkle_dsa_priv.pem)
#   REPO_URL - GitHub repository URL (default: auto-detect from git remote)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
VERSION_FILE="$ROOT_DIR/VERSION"

# Get version from argument or VERSION file
VERSION="${1:-$(cat "$VERSION_FILE" | tr -d '[:space:]')}"

# Get repo URL from argument, env var, or git remote
if [[ -n "${2:-}" ]]; then
  REPO_URL="$2"
elif [[ -n "${REPO_URL:-}" ]]; then
  REPO_URL="$REPO_URL"
else
  # Try to get from git remote
  REPO_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's/git@github.com:/https:\/\/github.com\//' || echo "")
  if [[ -z "$REPO_URL" ]]; then
    REPO_URL="https://github.com/jeevan-vj/windowsnap"
    echo "⚠️  Could not detect git remote, using default: $REPO_URL"
  fi
fi

DMG_NAME="WindowSnap-${VERSION}-macOS-notarized.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "❌ DMG not found: $DMG_PATH"
  echo "   Build the app first: bash scripts/build-universal-bundle.sh"
  exit 1
fi

# Find Sparkle tools (they're in Caskroom, not in PATH)
GENERATE_APPCAST=""
if command -v generate_appcast &> /dev/null; then
  GENERATE_APPCAST="generate_appcast"
elif [[ -d "/usr/local/Caskroom/sparkle" ]]; then
  # Find the latest version
  SPARKLE_VERSION=$(ls -t /usr/local/Caskroom/sparkle 2>/dev/null | grep -v metadata | head -1)
  if [[ -n "$SPARKLE_VERSION" ]] && [[ -f "/usr/local/Caskroom/sparkle/$SPARKLE_VERSION/bin/generate_appcast" ]]; then
    GENERATE_APPCAST="/usr/local/Caskroom/sparkle/$SPARKLE_VERSION/bin/generate_appcast"
  fi
elif [[ -d "/opt/homebrew/Caskroom/sparkle" ]]; then
  # Apple Silicon Mac
  SPARKLE_VERSION=$(ls -t /opt/homebrew/Caskroom/sparkle 2>/dev/null | grep -v metadata | head -1)
  if [[ -n "$SPARKLE_VERSION" ]] && [[ -f "/opt/homebrew/Caskroom/sparkle/$SPARKLE_VERSION/bin/generate_appcast" ]]; then
    GENERATE_APPCAST="/opt/homebrew/Caskroom/sparkle/$SPARKLE_VERSION/bin/generate_appcast"
  fi
fi

if [[ -z "$GENERATE_APPCAST" ]] || [[ ! -f "$GENERATE_APPCAST" ]]; then
  echo "❌ generate_appcast not found"
  echo "   Install: brew install sparkle"
  exit 1
fi

# Check for private key
PRIVATE_KEY="${SPARKLE_PRIVATE_KEY:-$HOME/.sparkle_dsa_priv.pem}"
if [[ ! -f "$PRIVATE_KEY" ]]; then
  echo "❌ Private key not found at $PRIVATE_KEY"
  echo "   Generate keys first: bash scripts/generate-sparkle-keys.sh"
  echo "   Or set SPARKLE_PRIVATE_KEY environment variable"
  exit 1
fi

# Create appcast directory
APPCAST_DIR="$DIST_DIR/appcast"
mkdir -p "$APPCAST_DIR"

# Copy DMG to appcast directory
echo "📦 Copying DMG to appcast directory..."
cp "$DMG_PATH" "$APPCAST_DIR/"

# Generate appcast
echo "🔨 Generating appcast.xml..."
DOWNLOAD_URL_PREFIX="${REPO_URL}/releases/download/v${VERSION}/"

if "$GENERATE_APPCAST" "$APPCAST_DIR" \
  --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
  --ed-key-file "$PRIVATE_KEY"; then
  echo ""
  echo "✅ Appcast generated successfully!"
  echo ""
  echo "📁 Appcast location: $APPCAST_DIR/appcast.xml"
  echo "📁 DMG location: $APPCAST_DIR/$DMG_NAME"
  echo ""
  echo "📋 Next steps:"
  echo "   1. Review appcast.xml: cat $APPCAST_DIR/appcast.xml"
  echo "   2. Upload appcast.xml to GitHub releases or your web server"
  echo "   3. Ensure SUFeedURL in Info.plist points to the appcast URL"
  echo ""
  echo "💡 For GitHub releases, you can:"
  echo "   - Upload appcast.xml as a release asset"
  echo "   - Or host it on a web server and point SUFeedURL there"
  echo ""
else
  echo "❌ Appcast generation failed"
  exit 1
fi

