#!/usr/bin/env bash
set -euo pipefail

# Development runner script for WindowSnap
# Builds and runs the app in debug mode

APP_NAME="WindowSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "🔧 WindowSnap Development Runner"
echo "================================"

# Check if we're in the right directory
if [[ ! -f "$ROOT_DIR/Package.swift" ]]; then
    echo "❌ Error: Package.swift not found. Are you in the right directory?"
    exit 1
fi

# Build in debug mode
echo "🏗️  Building in debug mode..."
cd "$ROOT_DIR"
swift build

# Get the binary path
BINARY_PATH="$(swift build --show-bin-path)/$APP_NAME"

if [[ ! -f "$BINARY_PATH" ]]; then
    echo "❌ Error: Binary not found at $BINARY_PATH"
    exit 1
fi

echo "🚀 Launching $APP_NAME..."
echo "   Binary: $BINARY_PATH"
echo "   Press Ctrl+C to stop"
echo ""

# Run the binary
"$BINARY_PATH"
