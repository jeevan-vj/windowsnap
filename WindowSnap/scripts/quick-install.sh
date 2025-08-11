#!/usr/bin/env bash
set -euo pipefail

# Quick install script for WindowSnap
# Builds, packages, and installs to /Applications in one step

APP_NAME="WindowSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"
INSTALL_DIR="/Applications"

echo "⚡ WindowSnap Quick Install"
echo "=========================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "⚠️  Please don't run this installer as root/sudo."
    echo "   The app will be installed to your Applications folder."
    exit 1
fi

# Step 1: Build the app
echo "[1/3] Building app bundle..."
bash "$SCRIPTS_DIR/build_bundle.sh"

# Step 2: Remove existing installation
if [[ -d "$INSTALL_DIR/${APP_NAME}.app" ]]; then
    echo "[2/3] Removing existing installation..."
    rm -rf "$INSTALL_DIR/${APP_NAME}.app"
else
    echo "[2/3] No existing installation found..."
fi

# Step 3: Install
echo "[3/3] Installing to $INSTALL_DIR..."
cp -R "$ROOT_DIR/dist/${APP_NAME}.app" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

echo ""
echo "✅ WindowSnap installed successfully!"
echo "   Location: $INSTALL_DIR/${APP_NAME}.app"
echo ""
echo "🚀 Launch options:"
echo "   • From Applications folder"
echo "   • From Spotlight: search 'WindowSnap'"
echo "   • From command line: open /Applications/${APP_NAME}.app"
echo ""

# Ask if user wants to launch now
read -p "🤔 Launch WindowSnap now? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Launching WindowSnap..."
    open "$INSTALL_DIR/${APP_NAME}.app"
fi
