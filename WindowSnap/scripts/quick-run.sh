#!/usr/bin/env bash
set -euo pipefail

# Quick rebuild and run - updates the dist/WindowSnap.app with new binary
# Uses developer certificate for consistent identity (preserves permissions)

APP_NAME="WindowSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"

echo "⚡ Quick rebuild and run"
echo "========================"

# Find Apple Development certificate
CODESIGN_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -1 | sed 's/.*"\(.*\)".*/\1/' || echo "")

if [[ -z "$CODESIGN_ID" ]]; then
    echo "⚠️  No Apple Development certificate found, using ad-hoc signing"
    CODESIGN_ID="-"
else
    echo "🔐 Using: $CODESIGN_ID"
fi

# Build debug binary
echo "🔨 Building..."
cd "$ROOT_DIR"
swift build

BINARY_PATH="$(swift build --show-bin-path)/$APP_NAME"

if [[ ! -f "$BINARY_PATH" ]]; then
    echo "❌ Binary not found"
    exit 1
fi

# Check if app bundle exists
if [[ ! -d "$APP_DIR" ]]; then
    echo "📦 App bundle not found, running full build first..."
    export CODESIGN_ID
    bash "$ROOT_DIR/scripts/build_bundle.sh"
else
    # Just copy the new binary to existing bundle
    echo "📋 Updating binary in app bundle..."
    cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
    chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"
    
    # Sign with developer certificate for consistent identity
    echo "🔏 Signing app bundle..."
    codesign --force --sign "$CODESIGN_ID" --deep "$APP_DIR" 2>/dev/null || {
        echo "⚠️  Signing failed, trying ad-hoc..."
        codesign --force --sign "-" "$APP_DIR" 2>/dev/null || true
    }
fi

# Kill existing instance if running
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5

echo "🚀 Launching..."
open "$APP_DIR"

echo "✅ Done! Check menu bar for WindowSnap icon."
echo ""
echo "💡 If permission still not working:"
echo "   1. Open System Settings → Privacy & Security → Screen Recording"
echo "   2. Remove old WindowSnap entries"
echo "   3. Run this script again and grant permission to the new entry"
