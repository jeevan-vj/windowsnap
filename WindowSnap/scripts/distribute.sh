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
- If macOS blocks the app: Right-click → Open, then click "Open" again
- For accessibility: System Preferences → Security & Privacy → Accessibility
- Add WindowSnap to the list and enable it

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
echo "🚀 Ready for distribution!"
