#!/usr/bin/env bash
set -euo pipefail

# Complete distribution script for WindowSnap
# Builds, packages, and prepares for distribution

APP_NAME="WindowSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
SCRIPTS_DIR="$ROOT_DIR/scripts"

echo "🚀 Starting WindowSnap distribution process..."

# Step 1: Clean previous builds
echo "[1/6] Cleaning previous builds..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Step 2: Build the app bundle
echo "[2/6] Building app bundle..."
bash "$SCRIPTS_DIR/build_bundle.sh"

# Step 3: Create DMG
echo "[3/6] Creating DMG package..."
bash "$SCRIPTS_DIR/package_dmg.sh"

# Step 4: Create installation script
echo "[4/6] Creating installation script..."
cat > "$DIST_DIR/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="WindowSnap"
INSTALL_DIR="/Applications"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🔧 Installing $APP_NAME..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "⚠️  Please don't run this installer as root/sudo."
    echo "   The app will be installed to your Applications folder."
    exit 1
fi

# Check if app bundle exists
if [[ ! -d "$SCRIPT_DIR/${APP_NAME}.app" ]]; then
    echo "❌ ${APP_NAME}.app not found in the same directory as this script."
    echo "   Please make sure both files are in the same folder."
    exit 1
fi

# Remove existing installation
if [[ -d "$INSTALL_DIR/${APP_NAME}.app" ]]; then
    echo "🗑️  Removing existing installation..."
    rm -rf "$INSTALL_DIR/${APP_NAME}.app"
fi

# Copy app to Applications
echo "📦 Copying ${APP_NAME}.app to $INSTALL_DIR..."
cp -R "$SCRIPT_DIR/${APP_NAME}.app" "$INSTALL_DIR/"

# Make sure it's executable
chmod +x "$INSTALL_DIR/${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

echo "✅ $APP_NAME installed successfully!"
echo "   You can now find it in your Applications folder."
echo "   To run from command line, use: open /Applications/${APP_NAME}.app"
EOF

chmod +x "$DIST_DIR/install.sh"

# Step 5: Create portable launch script
echo "[5/6] Creating portable launch script..."
cat > "$DIST_DIR/run.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="WindowSnap"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$SCRIPT_DIR/${APP_NAME}.app"

if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ ${APP_NAME}.app not found in $SCRIPT_DIR"
    echo "   Please make sure the app bundle is in the same directory as this script."
    exit 1
fi

echo "🚀 Launching $APP_NAME..."
open "$APP_PATH"
EOF

chmod +x "$DIST_DIR/run.sh"

# Step 6: Create README for distribution
echo "[6/6] Creating distribution README..."
cat > "$DIST_DIR/README.txt" <<EOF
WindowSnap Distribution Package
==============================

This package contains:
- WindowSnap.app     : The main application bundle
- WindowSnap.dmg     : Disk image for easy installation
- WindowSnap.zip     : Zip archive of the app bundle
- install.sh         : Installation script (copies to /Applications)
- run.sh            : Portable launcher (runs from current directory)
- README.txt        : This file

Installation Options:
====================

Option 1: DMG Installation (Recommended)
- Double-click WindowSnap.dmg
- Drag WindowSnap.app to Applications folder
- Launch from Applications or Spotlight

Option 2: Script Installation
- Run: bash install.sh
- This will copy the app to /Applications
- Launch from Applications or Spotlight

Option 3: Portable Mode
- Run: bash run.sh
- This runs the app from the current directory
- No installation required

Requirements:
============
- macOS 12.0 or later
- Accessibility permissions (app will request on first run)

Troubleshooting:
===============

Security Warning: "WindowSnap.app cannot be verified"
-----------------------------------------------------
If you see this warning when trying to open the app, use ONE of these methods:

Method 1 - Right-Click Open (Easiest):
  1. Right-click (or Control+click) WindowSnap.app
  2. Select "Open" from the menu
  3. Click "Open" in the confirmation dialog
  4. The app will open and macOS will remember this choice

Method 2 - Remove Quarantine Flag:
  Open Terminal and run:
    xattr -d com.apple.quarantine /Applications/WindowSnap.app

Method 3 - System Settings (macOS Ventura+):
  1. Try to open the app (it will be blocked)
  2. Go to System Settings → Privacy & Security
  3. Scroll down to see "WindowSnap was blocked"
  4. Click "Open Anyway"

Accessibility Permissions:
-------------------------
- System Preferences → Security & Privacy → Accessibility
- Add WindowSnap to the list and enable it
- This allows the app to move and resize windows

Version: 1.0
Build: $(date +%Y%m%d%H%M%S)
EOF

echo ""
echo "✅ Distribution complete!"
echo ""
echo "📦 Distribution files created in: $DIST_DIR"
echo "   - ${APP_NAME}.app (Application bundle)"
echo "   - ${APP_NAME}.dmg (Disk image)"
echo "   - ${APP_NAME}.zip (Zip archive)"
echo "   - install.sh (Installation script)"
echo "   - run.sh (Portable launcher)"
echo "   - README.txt (User instructions)"
echo ""

# Check if app is properly signed
if codesign --verify --verbose "$DIST_DIR/${APP_NAME}.app" 2>&1 | grep -q "Developer ID Application"; then
  echo "✅ App is properly code signed"
  if spctl -a -vv "$DIST_DIR/${APP_NAME}.app" 2>&1 | grep -q "accepted"; then
    echo "✅ App is notarized - ready for distribution!"
  else
    echo "⚠️  App is signed but NOT notarized"
    echo "   Users may see security warnings"
    echo "   Run: bash scripts/sign-and-notarize.sh"
  fi
else
  echo "⚠️  WARNING: App is NOT code signed!"
  echo "   Users WILL see 'App cannot be verified' error"
  echo ""
  echo "   User workarounds (add to documentation):"
  echo "   1. Right-click app → Open → Open"
  echo "   2. xattr -d com.apple.quarantine WindowSnap.app"
  echo ""
  echo "   To fix properly:"
  echo "   - Get Apple Developer account (\$99/year)"
  echo "   - Run: bash scripts/sign-and-notarize.sh"
  echo "   - See: DISTRIBUTION_GUIDE.md for details"
fi
echo ""
echo "🚀 Ready for distribution!"
