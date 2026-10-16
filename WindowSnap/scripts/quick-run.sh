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

# One stable identity (SIGNING_IDENTITY, else Developer ID for team 88282K637B,
# else Apple Development) so Screen Recording grants survive rebuilds.
CODESIGN_ID="${CODESIGN_ID:-}"
if [[ -n "$CODESIGN_ID" ]]; then
    echo "🔐 Using CODESIGN_ID: $CODESIGN_ID"
elif resolved_identity="$("$ROOT_DIR/scripts/resolve-local-signing-identity.sh")"; then
    IFS='|' read -r CODESIGN_ID resolved_team resolved_label <<<"$resolved_identity"
    echo "🔐 Using: $resolved_label (team ${resolved_team:-unknown})"
    if [[ -z "${TEAM_ID:-}" && -n "$resolved_team" ]]; then export TEAM_ID="$resolved_team"; fi
fi
if [[ -z "$CODESIGN_ID" || "$CODESIGN_ID" == "-" ]]; then
    if [[ "${REGION_SHARE_QA:-0}" == "1" ]]; then
        echo "❌ No signing identity; ad-hoc builds cannot keep a Screen Recording grant" >&2
        exit 1
    fi
    echo "⚠️  No signing identity found, using ad-hoc signing (not usable for Region Share QA)"
    CODESIGN_ID="-"
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
    if [[ "$CODESIGN_ID" == "-" ]]; then
        CODESIGN_ID="" ALLOW_ADHOC=1 bash "$ROOT_DIR/scripts/build_bundle.sh"
    else
        export CODESIGN_ID
        export WINDOWSNAP_LOCAL_SIGNING=1
        bash "$ROOT_DIR/scripts/build_bundle.sh"
    fi
else
    # Just copy the new binary to existing bundle
    echo "📋 Updating binary in app bundle..."
    cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
    chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"
    
    # Sign with developer certificate for consistent identity
    echo "🔏 Signing app bundle..."
    # Do not silently fall back to ad-hoc: that changes the code identity and
    # macOS stops matching the existing Screen Recording grant.
    codesign --force --sign "$CODESIGN_ID" --deep "$APP_DIR" || {
        echo "❌ Signing with $CODESIGN_ID failed; not falling back to ad-hoc" >&2
        exit 1
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
echo "   See 'Permission keeps asking' in docs/REGION_SHARE_PACKAGING.md"
