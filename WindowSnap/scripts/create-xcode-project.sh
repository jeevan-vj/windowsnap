#!/usr/bin/env bash
set -euo pipefail

# Script to create an Xcode project from the Swift Package
# This enables proper code signing and distribution options in Xcode

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "📦 Creating Xcode project from Swift Package..."
echo ""

# Check if Package.swift exists
if [[ ! -f "Package.swift" ]]; then
  echo "❌ Error: Package.swift not found"
  exit 1
fi

# Generate Xcode project
echo "Generating Xcode project..."
swift package generate-xcodeproj 2>/dev/null || {
  # If generate-xcodeproj fails (removed in newer Swift), use xcodebuild
  echo "Note: generate-xcodeproj not available, creating project manually..."
  
  # Create project using xcodebuild
  xcodebuild -list 2>/dev/null || {
    echo ""
    echo "Creating Xcode project structure..."
    echo ""
    echo "To create an Xcode project:"
    echo "1. Open Xcode"
    echo "2. File → New → Project"
    echo "3. Choose 'macOS' → 'App'"
    echo "4. Set Product Name: WindowSnap"
    echo "5. Set Bundle Identifier: com.windowsnap.app"
    echo "6. Choose a location"
    echo "7. In the new project, delete the default files"
    echo "8. File → Add Files to WindowSnap..."
    echo "9. Select the WindowSnap/WindowSnap directory"
    echo "10. Make sure 'Copy items if needed' is UNCHECKED"
    echo "11. Select 'Create groups'"
    echo ""
    echo "OR use Xcode's 'Open Package' feature:"
    echo "1. File → Open"
    echo "2. Navigate to WindowSnap directory"
    echo "3. Select Package.swift"
    echo "4. Click Open"
    echo ""
    exit 0
  }
}

echo ""
echo "✅ Xcode project should be available"
echo ""
echo "Next steps:"
echo "1. Open WindowSnap.xcodeproj in Xcode"
echo "2. Select the WindowSnap target"
echo "3. Go to 'Signing & Capabilities' tab"
echo "4. Select your Team"
echo "5. Xcode will automatically manage signing"
echo "6. Archive the app (Product → Archive)"
echo "7. Distribution options will now be available!"



