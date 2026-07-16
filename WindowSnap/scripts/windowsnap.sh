#!/usr/bin/env bash
set -euo pipefail

# Master script for WindowSnap - provides menu for all operations

APP_NAME="WindowSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"

show_menu() {
    echo ""
    echo "🪟 WindowSnap Management Console"
    echo "==============================="
    echo ""
    echo "Development:"
    echo "  1) Build and run (debug mode)"
    echo "  2) Build only"
    echo "  3) Clean build artifacts"
    echo "  4) Generate app icons"
    echo ""
    echo "Distribution:"
    echo "  5) Create verified production candidates"
    echo "  6) Build local-only ad-hoc package"
    echo "  7) Show release documentation"
    echo ""
    echo "Installation:"
    echo "  8) Quick install (build + install to /Applications)"
    echo "  9) Install existing build to /Applications"
    echo "  10) Uninstall from /Applications"
    echo ""
    echo "  0) Exit"
    echo ""
}

clean_build() {
    echo "🧹 Cleaning build artifacts..."
    rm -rf "$ROOT_DIR/.build"
    rm -rf "$ROOT_DIR/dist"
    echo "✅ Clean complete!"
}

install_existing() {
    local local_app="$ROOT_DIR/dist/local-only/${APP_NAME}.app"
    if [[ ! -d "$local_app" ]]; then
        echo "❌ No local-only app found. Run option 6 first."
        return 1
    fi
    
    echo "📦 Installing existing build to /Applications..."
    if [[ -d "/Applications/${APP_NAME}.app" ]]; then
        rm -rf "/Applications/${APP_NAME}.app"
    fi
    cp -R "$local_app" "/Applications/"
    chmod +x "/Applications/${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
    echo "✅ Installation complete!"
}

uninstall_app() {
    if [[ -d "/Applications/${APP_NAME}.app" ]]; then
        echo "🗑️  Uninstalling WindowSnap from /Applications..."
        rm -rf "/Applications/${APP_NAME}.app"
        echo "✅ Uninstall complete!"
    else
        echo "ℹ️  WindowSnap is not installed in /Applications"
    fi
}

while true; do
    show_menu
    read -p "Select option [0-10]: " choice
    
    case $choice in
        1)
            echo "🚀 Running development build..."
            bash "$SCRIPTS_DIR/dev-run.sh"
            ;;
        2)
            echo "🏗️  Building..."
            cd "$ROOT_DIR"
            swift build
            echo "✅ Build complete!"
            ;;
        3)
            clean_build
            ;;
        4)
            echo "🎨 Generating app icons..."
            bash "$SCRIPTS_DIR/generate-icons.sh"
            ;;
        5)
            echo "📦 Creating signed, notarized, and verified production candidates..."
            bash "$SCRIPTS_DIR/release.sh"
            ;;
        6)
            echo "🏗️  Building local-only package..."
            bash "$SCRIPTS_DIR/build-adhoc-release.sh"
            ;;
        7)
            echo "Production releases are documented in ../DISTRIBUTION_GUIDE.md"
            ;;
        8)
            echo "⚡ Quick install..."
            bash "$SCRIPTS_DIR/quick-install.sh"
            ;;
        9)
            install_existing
            ;;
        10)
            uninstall_app
            ;;
        0)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid option. Please select 0-10."
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
